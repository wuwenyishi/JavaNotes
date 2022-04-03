**大白话讲解 JDK 源码系列：从头到尾再讲一遍 ThreadLocal**



# 引言

其实网上有很多关于`ThreadLocal`的文章了，有不少文章也已经写的非常好了。但是很多同学反应还有一些部分没有讲解的十分清楚，还是有一定的疑惑没有想的十分清楚。因此本文主要结合常见的一些疑问、`ThreadLocal`源码、应用实例以注意事项来全面而深入地再详细讲解一遍`ThreadLocal`。希望大家看完本文后可以彻底掌握`ThreadLocal`。

# ThreadLocal 是什么？它能干什么？在阐述 ThreadLocal 之前



我们先来看下它的设计者是怎么描述 ThreadLocal 的吧。



![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/03/1841-7vODtI.png) 



看完官方的描述后，结合自己的理解，`ThreadLocal`提供了一种对应独立线程内的数据访问机制，实现了变量在线程之间隔离，在线程生命周期内独立获取或者设置的能力。如果我们想在线程内传递参数但是有不想作为方法参数的时候，`ThreadLocal`就可以排上用场了。不过值得注意的是`ThreadLocal`并不会解决变量共享问题。实际上从`ThreadLocal`的名称上面来看，线程本地变量也已经大致说明了它的作用，所以变量的命名还是非常重要的，要做到顾名思义。如果觉得还不是很理解，没关系，我们可以通过以下的场景再加深下理解。

假如有以下的场景，假设只有一个数据库连接，客户端 1、2、3 都需要获取数据库连接来进行具体的数据库操作，但是同一时间点只能有一个线程获取连接，其他线程只能等待。因此就会出现数据库访问效率不高的问题。



![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/03/1841-Ii1heK.png) 

那我们有没有什么办法能够避免线程等待的情况呢？上述问题的根本原因是数据库连接是共享变量，同时只能有一个线程可以进行操作。那如果三个线程都有自己的数据库连接，互相隔离，那不就不会出现等待的问题了嘛。那么此时我么可以使用`ThreadLocal`实现在不同线程中的变量隔离。可以看出来，`ThreadLocal`是一种已空间换取时间的做法。



![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/03/1841-KvDABW.png) 



# ThreadLocal 实现线程隔离的秘密



从上文中，我们了解到`ThreadLocal`可以实现变量访问的线程级别的隔离。那么它是到底如何实现的呢？这还需要结合`Thread`以及`ThreadLocal`的源码来分析才能揭开`ThreadLocal`实现线程隔离的神秘面纱。



```java
public class Thread implements Runnable {    
  ...    
  /* ThreadLocal values pertaining to this thread. This map is maintained     * by the ThreadLocal class. */    ThreadLocal.ThreadLocalMap threadLocals = null;    
  ...    
}
```

在 Thread 源码中我们发现，它有一个`threadLocals`变量，它的类型是`ThreadLocal`中的内部类`ThreadLocalMap`。我们在看下`ThreadLocalMap`的定义是怎样的。从源码中我们可以看出来，`ThreadLocalMap`实际上就是`Entry`数组，这个`Entry`对应的`key`实际就是`ThreadLocal`的实例，`value`就是实际的变量值。



```java
public class ThreadLocal<T> {  
  ...       
    static class ThreadLocalMap {           
      static class Entry extends WeakReference<ThreadLocal<?>> {            
        /** The value associated with this ThreadLocal. */            
        Object value;
            Entry(ThreadLocal<?> k, Object v) {                
              super(k);                
              value = v;            
            }        
      }       
      ...       
        //底层数据结构是数组       private Entry[] table;       
        ...        
    }  
  ...  
}
```

通过查看上述的源码，如果还不太好理解的话，我们再结合下现实中的例子来理解。大家都有支付宝账户，我们通过它来管理着我们的银行卡、余额、花呗这些金融服务。



![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/03/1843-t9HYeA.png) 

我们以支付宝以及支付宝账户进行类比，假设`ThreadLocal`就是支付宝，每个支付宝账户实际就是单独的线程，而账户中的余额属性就相当于`Thread`的私有属性`ThreadLocalMap`。我们在日常生活中，进行账户余额的充值或者消费，并不是直接通过账户进行操作的，而是借助于支付宝进行维护的。这就相当于每个线程对`ThreadLocalMap`进行操作的时候也不是直接操作的，而是借助于`ThreadLocal`来操作。



![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/03/1843-shmWjd.png) 



那么`Thread`到底是怎么借助`ThreadLocal`进行私有属性管理的呢？还是需要进一步查看`Thread`进行`set`以及`get`操作的源码。从以下的`ThreadLocal`的源码中我们可以看出，在进行操作之前，需要获取当前的执行操作的线程，再根据线程或者线程中私有的`ThreadLocalMap`属性来进行操作。



![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/03/1843-MEKOZR.png) 

在进行数据获取的时候，也是按照同样的流程，先获取当前的线程，再获取线程中对应的`ThreadLocalMap`属性来进行后续的值的获取。



![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/03/1843-mQOnEH.png) 

经过上述的源码的分析，我们可以得出这样的结论，`ThreadLocal`之所以可以实现变量的线程隔离访问，实际上就是借助于`Thread`中的`ThreadLocalMap`属性来进行操作。由于都是操作线程本身的属性，因此并不会影响其他线程中的变量值，因此可以实现线程级别的数据修改隔离。



![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/03/1844-LxGK5p.png) 



# 为什么 ThreadLocal 会出现 OOM 的问题？

## 内存泄漏演示

我们都知道，`ThreadLocal`如果使用不当的话会出现内存泄漏的问题，那么我们就通过下面的这段代码来分析下，内存泄漏的原因到底是什么。

```java
/** * @author mufeng * @description 测试ThreadLocal内存溢出 * @date 2022/1/16 19:01 * @since */public class ThreadLocalOOM {
    /**     * 测试线程池     */    
  private static Executor threadPool = new ThreadPoolExecutor(3, 3, 40,            
                                                              TimeUnit.SECONDS, new LinkedBlockingDeque<>());

    static class Info {       
      private byte[] info = new byte[10 * 1024 * 1024];    
                      }
    private  static ThreadLocal<Info> infoThreadLocal = new ThreadLocal<>();
    public static void main(String[] args) throws InterruptedException {
      for (int i = 0; i < 10; i++) {
        threadPool.execute(() -> {
          infoThreadLocal.set(new Info());                
          System.out.println("Thread started:" + Thread.currentThread().getName());            
        });            
        Thread.sleep(100);        
      }
    }}
```

手动进行`GC`之后，我们可以发现堆中仍然有超过 30M 的堆内存占用，如上面的代码，在线程池中活跃的线程会有三个，对应的`value`为 10M，说明在线程还存活的情况下，对应的`value`并没有被回收，因此存在内存泄漏的情况，如果存在大量线程的情况，就会出现`OOM`。



![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/03/1845-RAjABS.png) 

当我们修改代码在线程中进行`remove`操作，手动 GC 之后我们发现堆内存趋近于 0 了，之前没有被回收的对象已经被回收了。



![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/03/1845-YpRHil.png) 



## 内存泄漏问题分析



以上是对于 ThreadLocal 发生内存泄漏问题的演示，那么再来仔细分析下背后的原因是什么。ThreadLocal 中实际存储数据的是 ThreadLocalMap，实际上 Map 对应的 key 是一个虚引用，在 GC 的时候可以被回收掉，但是问题就在于 key 所对应的 value，它是强引用，只要线程存活，那么这条引用链就会一致存在，如果出现大量线程的时候就会有 OOM 的风险。所以在使用 ThreadLocal 的时候一定记得要显式的调用 remove 方法进行清理，防止内存泄漏。

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/03/1846-RKqK5A.png) 



# 父子线程的参数传递

到这里，我相信大家对于`ThreadLocal`的原理有了比较深入的理解了。结合上文中的`ThreadLocal`代码，不知道大家有没有思考过一个问题，我们在使用`ThreadLocal`的时候都是在同一个线程内进行了`set`以及`get`操作，那么如果`set`操作与`get`操作在父子线程中是否还可以正常的获取呢？带着这样的疑问，我们来看下如下的代码。

```java
/**
 * @author mufeng
 * @description 父子线程参数传递
 * @date 2022/1/16 9:54
 * @since
 */
public class InheritableThreadLocalMain {

    private static final ThreadLocal<String> count = new ThreadLocal<>();

    public static void main(String[] args) {

        count.set("父子线程参数传递！！！");
        System.out.println(Thread.currentThread().getName() + ":" + count.get());

        new Thread(() -> {
            System.out.println(Thread.currentThread().getName() + ":" + count.get());
        }).start();

    }

}
```

与之前代码有所不同，ThreadLocal 的设值是在 main 线程中进行的，但是获取操作实际是在主线程下的子线程中进行的，大家可以分析一下运行结果是怎么样的。

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/03/1847-ZMlQhj.png) 

看到这个运行结果，不知道大家分析的对不对呢。实际上如果理解了上文的核心的话，这个问题应该很好分析的。`ThreadLocal`获取数据的时候，首先是需要获取当前的线程的，根据线程获取实际存储数据的`ThreadLocalMap`，上文代码中设置和获取在父子线程中进行，那肯定是获取不到设置的数据的。但是在现实的项目开发中，我们会经常遇到需要将父线程的变量值传递给子线程进行处理，那么应该要怎么来实现呢？这个时候`InheritableThreadLocal`就派上用场了。

```java
/**
 * @author mufeng
 * @description 父子线程参数传递
 * @date 2022/1/16 9:54
 * @since
 */
public class InheritableThreadLocalMain {

    private static final ThreadLocal<String> count = new InheritableThreadLocal<>();

    public static void main(String[] args) {

        count.set("父子线程参数传递！！！");
        System.out.println(Thread.currentThread().getName() + ":" + count.get());

        new Thread(() -> {
            System.out.println(Thread.currentThread().getName() + ":" + count.get());
        }).start();

    }

}
```

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/03/1847-FmOhqq.png) 

那么`InheritableThreadLocal`到底是如何实现父子线程的参数传递的呢？我么还是的看看源码中的实现原理。实际上在`Thread`源码中，除了有`Threadlocal`私有属性还有`InheritableThreadLocal`私有属性。

```java
public class Thread implements Runnable {
    
     /* ThreadLocal values pertaining to this thread. This map is maintained
     * by the ThreadLocal class. */
    ThreadLocal.ThreadLocalMap threadLocals = null;

    /*
     * InheritableThreadLocal values pertaining to this thread. This map is
     * maintained by the InheritableThreadLocal class.
     */
    ThreadLocal.ThreadLocalMap inheritableThreadLocals = null;
...
    public Thread(Runnable target) {
        init(null, target, "Thread-" + nextThreadNum(), 0);
    }
    
    private void init(ThreadGroup g, Runnable target, String name,
                      long stackSize) {
        init(g, target, name, stackSize, null, true);
    }
    
    private void init(ThreadGroup g, Runnable target, String name,
                      long stackSize, AccessControlContext acc,
                      boolean inheritThreadLocals) {
        ...
        //关键
         if (inheritThreadLocals && parent.inheritableThreadLocals != null)
            this.inheritableThreadLocals =
                ThreadLocal.createInheritedMap(parent.inheritableThreadLocals); 
        ...    
        
    }
    ...
    
}
```

实际在进行子线程创建的时候，在线程初始化过程中，判断了父线程中的`inheritableThreadLocals`属性是否为空，如果不为空的话需要进行值的复制，这样便实现了父子线程的值传递。

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/03/1847-0CGIYT.png) 

# 总结

本文主要对`ThreadLocal`进行了相对全面的分析，从它的使用场景、原理以及源码分析、产生`OOM`的原因以及一些使用上的注意，相信通过本文的学习，大家对于`ThreadLocal`会有更加深刻的理解。

