# Redis为什么这么快



## 前言

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2137-zotIpe.awebp)

说起当前主流NoSql数据库非 `Redis` 莫属。因为它读写速度极快，一般用于缓存热点数据加快查询速度，大家在工作里面也肯定和 `Redis` 打过交道，但是对于`Redis` 为什么快，除了对八股文的背诵，好像都还没特别深入的了解。

今天我们一起深入的了解下redis吧：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2137-d1hpKQ.awebp)

### 高效的数据结构

Redis 的底层数据结构一共有6种，分别是，简单动态字符串，双向链表，压缩列表，哈希表，跳表和整数数组，它们和数据类型的对应关系如下图所示：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2137-0rFGHF.awebp)

> **本文暂时按下不表，后续会针对以上所有数据结构进行源码级深入分析**

### 单线程vs多线程

![多线程VS单线程](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2137-G4xFb6.awebp)

在学习计算机操作系统时一定遇到过这个问题： **多线程一定比单线程快吗？** 相信各位看官们一定不会像上面的傻哪吒一样落入敖丙的圈套中。

多线程有时候确实比单线程快，但也有很多时候没有单线程那么快。首先用一张3岁小孩都能看懂的图解释并发与并行的区别：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2137-NwyntJ.awebp)

> - 并发(concurrency)：指在同一时刻只能有一条指令执行，但多个进程指令被快速的轮换执行，使得在宏观上具有多个进程同时执行的效果，但在微观上并不是同时执行的，只是把时间分成若干段，使多个进程快速交替的执行。
> - 并行(parallel)：指在同一时刻，有多条指令在多个处理器上同时执行。所以无论从微观还是从宏观来看，二者都是一起执行的。

不难发现并发在同一时刻只有一条指令执行，只不过进程(线程)在CPU中快速切换，速度极快，给人看起来就是“同时运行”的印象，实际上同一时刻只有一条指令进行。但实际上如果我们在一个应用程序中使用了多线程，**线程之间的轮换以及上下文切换是需要花费很多时间的**。



> **Talk is cheap,Show me the code**

如下代码演示了串行和并发执行并累加操作的时间：

```JAVA
public class ConcurrencyTest {
    private static final long count = 1000000000;

    public static void main(String[] args) {
        try {
            concurrency();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        serial();
    }

    private static void concurrency() throws InterruptedException {
        long start = System.currentTimeMillis();
        Thread thread = new Thread(new Runnable() {

            @Override
            public void run() {
                 int a = 0;
                 for (long i = 0; i < count; i++)
                 {
                     a += 5;
                 }
            }
        });
        thread.start();
        int b = 0;
        for (long i = 0; i < count; i++) {
            b--;
        }
        thread.join();
        long time = System.currentTimeMillis() - start;
        System.out.println("concurrency : " + time + "ms,b=" + b);
    }

    private static void serial() {
        long start = System.currentTimeMillis();
        int a = 0;
        for (long i = 0; i < count; i++)
        {
            a += 5;
        }
        int b = 0;
        for (long i = 0; i < count; i++) {
            b--;
        }
        long time = System.currentTimeMillis() - start;
        System.out.println("serial : " + time + "ms,b=" + b);
    }

}
复制代码
```

执行时间如下表所示，不难发现，当并发执行累加操作不超过百万次时，速度会比串行执行累加操作要慢。

| 循环次数 | 串行执行耗时/ms | 并发执行耗时 | 并发比串行快多少 |
| -------- | --------------- | ------------ | ---------------- |
| 1亿      | 130             | 77           | 约1倍            |
| 1千万    | 18              | 9            | 约1倍            |
| 1百万    | 5               | 5            | 相差无几         |
| 10万     | 4               | 3            | 相差无几         |
| 1万      | 0               | 1            | 慢               |

由于线程有创建和上下文切换的开销，导致并发执行的速度会比串行慢的情况出现。

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2138-M4CHpn.awebp)

#### 上下文切换

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2137-HCYEdt.awebp)

多个线程可以执行在单核或多核CPU上，单核CPU也支持多线程执行代码，CPU通过给每个线程分配CPU时间片(机会)来实现这个机制。CPU为了执行多个线程，就需要不停的切换执行的线程，这样才能保证所有的线程在一段时间内都有被执行的机会。



此时，CPU分配给每个线程的执行时间段，称作它的时间片。CPU时间片一般为几十毫秒。CPU通过时间片分配算法来循环执行任务，当前任务执行一个时间片后切换到下一个任务。

但是，在切换前会保存上一个任务的状态，以便下次切换回这个任务时，可以再加载这个任务的状态。所以**任务从保存到再加载的过程就是一次上下文切换**。

**根据多线程的运行状态来说明**：多线程环境中，当一个线程的状态由Runnable转换为非Runnable(Blocked、Waiting、Timed_Waiting)时，相应线程的上下文信息(包括CPU的寄存器和程序计数器在某一时间点的内容等)需要被保存，以便相应线程稍后再次进入Runnable状态时能够在之前的执行进度的基础上继续前进。而一个线程从非Runnable状态进入Runnable状态可能涉及恢复之前保存的上下文信息。这个对线程的上下文进行保存和恢复的过程就被称为上下文切换。

### 基于内存

以MySQL为例，MySQL的数据和索引都是持久化保存在磁盘上的，因此当我们使用SQL语句执行一条查询命令时，如果目标数据库的索引还没被加载到内存中，那么首先要先把索引加载到内存，再通过若干寻址定位和磁盘I/O，把数据对应的磁盘块加载到内存中，最后再读取数据。

如果是机械硬盘，那么首先需要找到数据所在的位置，即需要读取的磁盘地址。可以看看这张示意图：

![磁盘结构示意图](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2139-O5MuVp.awebp)

读取硬盘上的数据，第一步就是找到所需的磁道，磁道就是以中间轴为圆心的圆环，首先我们需要找到所需要对准的磁道，并将磁头移动到对应的磁道上，这个过程叫做寻道。

然后，我们需要等到磁盘转动，让磁头指向我们需要读取的数据开始的位置，这里耗费的时间称为旋转延迟，平时我们说的硬盘转速快慢，主要影响的就是耗费在这里的时间，而且这个转动的方向是单向的，如果错过了数据的开头位置，就必须等到盘片旋转到下一圈的时候才能开始读。

最后，磁头开始读取记录着磁盘上的数据，这个原理其实与光盘的读取原理类似，由于磁道上有一层磁性介质，当磁头扫过特定的位置，磁头感应不同位置的磁性状态就可以将磁信号转换为电信号。

可以看到，无论是磁头的移动还是磁盘的转动，本质上其实都是机械运动，这也是为什么这种硬盘被称为机械硬盘，而机械运动的效率就是磁盘读写的瓶颈。

扯得有点远了，我们说回redis，如果像Redis这样把数据存在内存中，读写都直接对数据库进行操作，天然地就比硬盘数据库少了到磁盘读取数据的这一步，而这一步恰恰是计算机处理I/O的瓶颈所在。

在内存中读取数据，本质上是电信号的传递，比机械运动传递信号要快得多。

![硬盘数据库读取流程](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2139-WSJTlQ.awebp)

![内存数据库读取流程](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2139-lY3vO7.awebp)

因此，可以负责任地说，Redis这么快当然跟它基于内存运行有着很大的关系。但是，这还远远不是全部的原因。



#### Redis FAQ

面对单线程的 Redis 你也许又会有疑问：敖丙，我的多核CPU发挥不了作用了呀！别急，Redis 针对这个问题专门进行了解答。

![img](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/6b53f6e39ba94446a72688eff01b2794~tplv-k3u1fbpfcp-zoom-in-crop-mark:1304:0:0:0.awebp)

> CPU成为Redis性能瓶颈的情况并不常见，因为Redis通常会受到内存或网络的限制。例如，在 Linux 系统上使用流水线 Redis 每秒甚至可以提供 100 万个请求，所以如果你的应用程序主要使用O(N)或O(log(N))命令，它几乎不会占用太多的CPU。
>
> 然而，为了最大化CPU利用率，你可以在同一个节点中启动多个Redis实例，并将它们视为不同的Redis服务。在某些情况下，一个单独的节点可能是不够的，所以如果你想使用多个cpu，你可以开始考虑一些更早的分片方法。
>
> 你可以在[Partitioning页面](https://link.juejin.cn?target=https%3A%2F%2Fredis.io%2Ftopics%2Fpartitioning)中找到更多关于使用多个Redis实例的信息。
>
> 然而，在Redis 4.0中，我们开始让Redis更加线程化。目前这仅限于在后台删除对象，以及阻塞通过Redis模块实现的命令。对于未来的版本，我们的计划是让Redis变得越来越多线程。

> **注意：我们一直说的 Redis 单线程，只是在处理我们的网络请求的时候只有一个线程来处理**，一个正式的Redis Server运行的时候肯定是不止一个线程的！
>
> 例如Redis进行持久化的时候会 fork了一个子进程 执行持久化操作

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2140-ixWcWu.awebp)

### 四种IO模型

当一个网络IO发生(假设是read)时，它会涉及两个系统对象，一个是调用这个IO的进程，另一个是系统内核。




当一个read操作发生时，它会经历两个阶段：

​	①等待数据准备；

​	②将数据从内核拷贝到进程中。

为了解决网络IO中的问题，提出了4中网络IO模型：

- 阻塞IO模型
- 非阻塞IO模型
- 多路复用IO模型
- 异步IO模型

> 阻塞和非阻塞的概念描述的是用户线程调用内核IO操作的方式：阻塞时指IO操作需要彻底完成后才返回到用户空间；而非阻塞是指IO操作被调用后立即返回给用户一个状态值，不需要等到IO操作彻底完成。

#### 阻塞IO模型

在Linux中，默认情况下所有socket都是阻塞的，一个典型的读操作如下图所示：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2140-OijEzc.awebp)

当应用进程调用了recvfrom这个系统调用后，系统内核就开始了IO的第一个阶段：准备数据。

对于网络IO来说，很多时候数据在一开始还没到达时(比如还没有收到一个完整的TCP包)，系统内核就要等待足够的数据到来。而在用户进程这边，整个进程会被阻塞。

当系统内核一直等到数据准备好了，它就会将数据从系统内核中拷贝到用户内存中，然后系统内核返回结果，用户进程才解除阻塞的状态，重新运行起来。所以，阻塞IO模型的特点就是在IO执行的两个阶段(等待数据和拷贝数据)都被阻塞了。

#### 非阻塞IO模型

在Linux中，可以通过设置socket使IO变为非阻塞状态。当对一个非阻塞的socket执行read操作时，读操作流程如下图所示：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2141-5ARvQ5.awebp)

从图中可以看出，当用户进程发出 read 操作时，如果内核中的数据还没有准备好，那么它不会阻塞用户进程，而是立刻返回一个错误。

从用户进程角度讲，它发起一个read操作后，并不需要等待，而是马上就得到了一个结果。当用户进程判断结果是一个错误时，它就知道数据还没有准备好，于是它可以再次发送read操作。

一旦内核中的数据准备好了，并且又再次收到了用户进程的系统调用，那么它马上就将数据复制到了用户内存中，然后返回正确的返回值。

**所以，在非阻塞式IO中，用户进程其实需要不断地主动询问kernel数据是否准备好。非阻塞的接口相比阻塞型接口的显著差异在于被调用之后立即返回。**

#### 多路复用IO模型

多路IO复用，有时也称为事件驱动IO（**Reactor设计模式**）。它的基本原理就是有个函数会不断地轮询所负责的所有socket，当某个socket有数据到达了，就通知用户进程，多路IO复用模型的流程如图所示：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2141-vP4vpz.awebp)

当用户进程调用了select，那么整个进程会被阻塞，而同时，内核会"监视"所有select负责的socket，当任何一个socket中的数据准备好了，select就会返回。这个时候用户进程再调用read操作，将数据从内核拷贝到用户进程。

这个模型和阻塞IO的模型其实并没有太大的不同，事实上还更差一些。因为这里需要使用两个系统调用(select和recvfrom)，而阻塞IO只调用了一个系统调用(recvfrom)。但是，用select的优势在于它可以同时处理多个连接。所以，如果系统的连接数不是很高的话，使用select/epoll的web server不一定比使用多线程的阻塞IO的web server性能更好，可能延迟还更大；**select/epoll的优势并不是对单个连接能处理得更快，而是在于能处理更多的连接。**

如果select()发现某句柄捕捉到了"可读事件"，服务器程序应及时做recv()操作，并根据接收到的数据准备好待发送数据，并将对应的句柄值加入writefds，准备下一次的"可写事件"的select()检测。同样，如果select()发现某句柄捕捉到"可写事件"，则程序应及时做send()操作，并准备好下一次的"可读事件"检测准备。

如下图展示了基于事件驱动的工作模型，当不同的事件产生时handler将感应到并执行相应的事件，像一个多路开关似的。

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2141-qUOMLB.awebp)

**IO多路复用是最常使用的IO模型，但是其异步程度还不够“彻底”，因为它使用了会阻塞线程的select系统调用。因此IO多路复用只能称为异步阻塞IO，而非真正的异步IO。**

#### 异步IO模型

“真正”的异步IO需要操作系统更强的支持。如下展示了异步 IO 模型的运行流程(**Proactor设计模式**)：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2141-6MjDLP.awebp)

用户进程发起read操作之后，立刻就可以开始去做其他的事；而另一方面，从内核的角度，当它收到一个异步的read请求操作之后，首先会立刻返回，所以不会对用户进程产生任何阻塞。

然后，内核会等待数据准备完成，然后将数据拷贝到用户内存中，当这一切都完成之后，内核会给用户进程发送一个信号，返回read操作已完成的信息。

#### IO模型总结

调用阻塞IO会一直阻塞住对应的进程直到操作完成，而非阻塞IO在内核还在准备数据的情况下会立刻返回。

两者的区别就在于同步IO进行IO操作时会阻塞进程。按照这个定义，之前所述的阻塞IO、非阻塞IO及多路IO复用都属于同步IO。实际上，真实的IO操作，就是例子中的recvfrom这个系统调用。

非阻塞IO在执行recvfrom这个系统调用的时候，如果内核的数据没有准备好，这时候不会阻塞进程。但是当内核中数据准备好时，recvfrom会将数据从内核拷贝到用户内存中，这个时候进程则被阻塞。

而异步IO则不一样，当进程发起IO操作之后，就直接返回，直到内核发送一个信号，告诉进程IO已完成，则在这整个过程中，进程完全没有被阻塞。

各个IO模型的比较如下图所示：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2142-7L1ai6.awebp)

### Redis中的应用

Redis服务器是一个事件驱动程序，服务器需要处理以下两类事件：

- **文件事件**：Redis服务端通过套接字与客户端(或其他Redis服务器)进行连接，而文件事件就是服务器对套接字操作的抽象。服务器与客户端(或者其他服务器)的通信会产生相应的文件事件，而服务器则通过监听并处理这些事件来完成一系列网络通信操作。
- **时间事件**：Redis服务器中的一些操作(如`serverCron`)函数需要在给定的时间点执行，而时间事件就是服务器对这类定时操作的抽象。

#### I/O多路复用程序

Redis的 I/O 多路复用程序的所有功能都是通过包装常见的`select`、`epoll`、`evport`、`kqueue`这些多路复用函数库来实现的。

因为Redis 为每个 I/O 多路复用函数库都实现了相同的API，所以I/O多路复用程序的底层实现是可以互换的。

Redis 在 I/O 多路复用程序的实现源码中用 `#include` 宏定义了相应的规则，程序会在编译时自动选择系统中性能最高的 I/O 多路复用函数库来作为 Redis 的 I/O 多路复用程序的底层实现(`ae.c`文件)：

```c++
/* Include the best multiplexing layer supported by this system.
 * The following should be ordered by performances, descending. */
#ifdef HAVE_EVPORT
#include "ae_evport.c"
#else
    #ifdef HAVE_EPOLL
    #include "ae_epoll.c"
    #else
        #ifdef HAVE_KQUEUE
        #include "ae_kqueue.c"
        #else
        #include "ae_select.c"
        #endif
    #endif
#endif
复制代码
```

#### 文件事件处理器

**Redis基于 Reactor 模式开发了自己的网络事件处理器：这个处理器被称为文件事件处理器：**

- **文件事件处理器使用 I/O 多路复用程序来同时监听多个套接字**，并根据套接字目前执行的任务来为套接字关联不同的事件处理器。
- 当被监听的套接字准备好执行连接应答(`accept`)、读取(`read`)、写入(`write`)、关闭(`close`)等操作时，与操作相对应的文件事件就会产生，这时文件事件处理器就会调用套接字之前关联好的事件处理器来处理这些事件。

下图展示了文件事件处理器的四个组成部分：`套接字`、`I/O多路复用程序`、`文件事件分派器(dispatcher)`、`事件处理器`。

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2142-v2VxIm.awebp)

文件事件是对套接字操作的抽象，每当一个套接字准备好执行连接应答、写入、读取、关闭等操作时，就会产生一个文件事件。因为一个服务器通常会连接多个套接字，所以多个文件事件有可能会并发地出现。**I/O ** **多路复用程序负责监听多个套接字，并向文件事件分派器传送那些产生了事件的套接字。**

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2143-ySJ06h.awebp)

哪吒问的问题很棒，联想一下，生活中一群人去食堂打饭，阿姨说的最多的一句话就是：**排队啦！排队啦！一个都不会少！**

没错，一切来源生活！Redis 的 I/O多路复用程序总是会将所有产生事件的套接字都放到一个队列里面，然后通过这个队列，以有序、同步、每次一个套接字的方式向文件事件分派器传送套接字。当上一个套接字产生的事件被处理完毕之后，I/O 多路复用程序才会继续向文件事件分派器传送下一个套接字。

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2142-NcOQBO.awebp)

Redis为文件事件处理器编写了多个处理器，这些事件处理器分别用于实现不同的网络通信需求：

- 为了对连接服务器的各个客户端进行应答，服务器要为监听套接字关联`连接应答处理器`；
- 为了接受客户端传来的命令请求，服务器要为客户端套接字关联`命令请求处理器` ；
- 为了向客户端返回命令的执行结果，服务器要为客户端套接字关联`命令回复处理器` ；
- 当主服务器和从服务器进行复制操作时，主从服务器都需要关联特别为复制功能编写的`复制处理器`。

##### 连接应答处理器

`networking.c/acceptTcpHandler`函数是Redis的连接应答处理器，这个处理器用于对连接服务器监听套接字的客户端进行应答，具体实现为`sys/socket.h/acccept`函数的包装。

当Redis服务器进行初始化的时候，程序会将这个连接应答处理器和服务器监听套接字的`AE_READABLE`时间关联起来，当有客户端用`sys/socket.h/connect`函数连接服务器监听套接字的时候，套接字就会产生`AE_READABLE`事件，引发连接应答处理器执行，并执行相应的套接字应答操作。

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2143-i2w8vN.awebp)

##### 命令请求处理器

`networking.c/readQueryFromClient`函数是Redis的命令请求处理器，这个处理器负责从套接字中读入客户端发送的命令请求内容，具体实现为`unistd.h/read`函数的包装。

当一个客户端通过连接应答处理器成功连接到服务器之后，服务器会将客户端套接字的`AE_READABLE`事件和命令请求处理器关联起来，当客户端向服务器发送命令请求的时候，套接字就会产生`AE_READABLE`事件，引发命令请求处理器执行，并执行相应的套接字读入操作。

在客户端连接服务器的整个过程中，服务器都会一直为客户端套接字`AE_READABLE`事件关联命令请求处理器。

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2143-jYdjob.awebp)

##### 命令回复处理器

`networking.c/sendReplyToClient`函数是Redis的命令回复处理器，这个处理器负责从服务器执行命令后得到的命令回复通过套接字返回给客户端，具体实现为`unistd.h/write`函数的包装。

当服务器有命令回复需要传送给客户端的时候，服务器会将客户端套接字的`AE_WRITABLE`事件和命令回复处理器关联起来，当客户端准备好接收服务器传回的命令回复时，就会产生`AE_WRITABLE`事件，引发命令回复处理器执行，并执行相应的套接字写入操作。

当命令回复发送完毕之后，服务器就会解除命令回复处理器与客户端套接字的`AE_WRITABLE`事件之间的关联。

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2144-nt3AGl.awebp)

#### 小总结

一句话描述 IO 多路复用在 Redis 中的应用：Redis 将所有产生事件的套接字都放到一个队列里面，以有序、同步、每次一个套接字的方式向文件事件分派器传送套接字，文件事件分派器根据套接字对应的事件选择响应的处理器进行处理，从而实现了高效的网络请求。

### Redis的自定义协议

Redis客户端使用RESP（[Redis的序列化协议](https://link.juejin.cn?target=https%3A%2F%2Fredis.io%2Ftopics%2Fprotocol)）协议与Redis的服务器端进行通信。 它实现简单，解析快速并且人类可读。

RESP 支持以下数据类型：简单字符串、错误、整数、批量字符串和数组。

RESP 在 Redis 中用作请求-响应协议的方式如下：

- 客户端将命令作为批量字符串的 RESP 数组发送到 Redis 服务器。
- 服务器根据命令实现以其中一种 RESP 类型进行回复。

在 RESP 中，某些数据的类型取决于第一个字节：

- 对于**简单字符串**，回复的第一个字节是“+”
- 对于**错误**，回复的第一个字节是“-”
- 对于**整数**，回复的第一个字节是“:”
- 对于**批量字符串**，回复的第一个字节是“$”
- 对于**数组**，回复的第一个字节是“*”

此外，RESP 能够使用稍后指定的批量字符串或数组的特殊变体来表示 Null 值。在 RESP 中，协议的不同部分总是以“\r\n”（CRLF）终止。

> **下面只简单介绍字符串的编码方式和错误的编码方式，详情可以查看 Redis 官网对 RESP 进行了详细的说明。**

#### 简单字符串

用如下方法编码：一个“+”号后面跟字符串，最后是“\r\n”，字符串里不能包含"\r\n"。简单字符串用来传输比较短的二进制安全的字符串。例如很多redis命令执行成功会返回“OK”，用RESP编码就是5个字节：

```
"+OK\r\n"
复制代码
```

想要发送二进制安全的字符串，需要用RESP的块字符串。当redis返回了一个简单字符串的时候，客户端库需要给调用者返回“+”号（不含）之后CRLF之前（不含）的字符串。

#### **RESP错误**

RESP 有一种专门为错误设计的类型。实际上错误类型很像RESP简单字符串类型，但是第一个字符是“-”。简单字符串类型和错误类型的区别是客户端把错误类型当成一个异常，错误类型包含的字符串是异常信息。格式是：

```
"-Error message\r\n"
复制代码
```

有错误发生的时候才会返回错误类型，例如你执行了一个对于某类型错误的操作，或者命令不存在等。当返回一个错误类型的时候客户端库应该发起一个异常。下面是一个错误类型的例子

```
-ERR unknown command 'foobar' -WRONGTYPE Operation against a key holding the wrong kind of value
复制代码
```

“-”号之后空格或者换行符之前的字符串代表返回的错误类型，这只是惯例，并不是RESP要求的格式。例如ERR是一般错误，WRONGTYPE是更具体的错误表示客户端的试图在错误的类型上执行某个操作。这个称为错误前缀，能让客户端更方便的识别错误类型。

客户端可能为不同的错误返回不同的异常，也可能只提供一个一般的方法来捕捉错误并提供错误名。但是不能依赖客户端提供的这些特性，因为有的客户端仅仅返回一般错误，比如false。

#### 高性能 Redis 协议分析器

尽管 Redis 的协议非常利于人类阅读， 定义也很简单， 但这个协议的实现性能仍然可以和二进制协议一样快。

因为 Redis 协议将数据的长度放在数据正文之前， 所以程序无须像 JSON 那样， 为了寻找某个特殊字符而扫描整个 payload ， 也无须对发送至服务器的 payload 进行转义（quote）。

程序可以在对协议文本中的各个字符进行处理的同时， 查找 CR 字符， 并计算出批量回复或多条批量回复的长度， 就像这样：

```C
#include <stdio.h>

int main(void) {
    unsigned char *p = "$123\r\n";
    int len = 0;

    p++;
    while(*p != '\r') {
        len = (len*10)+(*p - '0');
        p++;
    }

    /* Now p points at '\r', and the len is in bulk_len. */
    printf("%d\n", len);
    return 0;
}
复制代码
```

得到了批量回复或多条批量回复的长度之后， 程序只需调用一次 `read` 函数， 就可以将回复的正文数据全部读入到内存中， 而无须对这些数据做任何的处理。在回复最末尾的 CR 和 LF 不作处理，丢弃它们。

Redis 协议的实现性能可以和二进制协议的实现性能相媲美， 并且由于 Redis 协议的简单性， 大部分高级语言都可以轻易地实现这个协议， 这使得客户端软件的 bug 数量大大减少。

### 冷知识：redis到底有多快？

在成功安装了Redis之后，Redis自带一个可以用来进行性能测试的命令 redis-benchmark，通过运行这个命令，我们可以模拟N个客户端同时发送请求的场景，并监测Redis处理这些请求所需的时间。

根据官方的文档，Redis经过在60000多个连接中进行了基准测试，并且仍然能够在这些条件下维持50000 q/s的效率，同样的请求量如果打到MySQL上，那肯定扛不住，直接就崩掉了。也是因为这个原因，Redis经常作为缓存存在，能够起到对数据库的保护作用。

![官方给的Redis效率测试统计图[1]（横坐标是连接数量，纵坐标是QPS）](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2144-0YnFDL.awebp)

可以看出来啊，Redis号称十万吞吐量确实也没吹牛，以后大家面试的时候也可以假装不经意间提一嘴这个数量级，发现很多人对“十万级“、”百万级“这种量级经常乱用，能够比较精准的说出来也是一个加分项呢。


作者：敖丙
链接：https://juejin.cn/post/7049148028875178020
来源：稀土掘金
著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。