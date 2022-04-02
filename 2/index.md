# 浅谈 ThreadLocal 的实际运用             



ThreadLocal 是 JDK 1.2 提供的一个工具，作者其一也是我们耳熟能详的大佬 Doug Lea

这个工具主要是为了解决**多线程下共享资源的问题**

接下来我们从 ThreadLocal 的定义以及适用场景一步步扒开它的外衣



## 适用场景

- 场景1，ThreadLocal 用作保存每个线程独享的对象，为每个线程都创建一个副本，这样每个线程都可以修改自己所拥有的副本, 而不会影响其他线程的副本，确保了线程安全。
- 场景2，ThreadLocal  用作每个线程内需要独立保存信息，以便供其他方法更方便地获取该信息的场景。每个线程获取到的信息可能都是不一样的，前面执行的方法保存了信息后，后续方法可以通过 ThreadLocal 直接获取到，避免了传参，类似于全局变量的概念。

### 场景1

我们去饭店点了一桌子菜，有面条，有炒菜，有卤味。这个饭店的厨师很热情，每个厨师都想下面给你吃，第一个厨师给这个面放了一把盐巴，第二个厨师不知道也给了这个面放了盐巴，第三个厨师不知道也给了这个面放了盐巴，第四个厨师.......

这就好比多线程下，线程不安全的问题了

所以 Doug Lea 说，你们一人负责做一道菜，不要瞎胡闹

接下来我们上下代码来演示一下这个简单的例子（100个线程都要用到 SimpleDateFormat）

```java
public static ExecutorService threadPool = Executors.newFixedThreadPool(16);
static SimpleDateFormat dateFormat = new SimpleDateFormat("mm:ss");

public static void main(String[] args) throws InterruptedException {
    for (int i = 0; i < 100; i++) {
        int finalI = i;
        threadPool.submit(new Runnable() {
            @Override
            public void run() {
                String date = new ThreadLocalDemo01().date(finalI);
                System.out.println(date);
            }
        });
    }
    threadPool.shutdown();
}

public String date(int seconds) {
    Date date = new Date(1000 * seconds);
    return dateFormat.format(date);
}


输出：
00:05
00:07
00:05
00:05
00:06
00:05
00:05
00:11
00:05
00:12
00:10
  
复制代码
```

执行上面的代码就会发现，控制台所打印出来的和我们所期待的是不一致的

我们所期待的是打印出来的时间是不重复的，但是可以看出在这里出现了重复，比如第一行和第三行都是 05 秒，这就代表它内部已经出错了。

这时候是不是有机智的同学说，并发问题加锁不就解决了吗，that is good idea



代码改一下变成这样

```java
    public static ExecutorService threadPool = Executors.newFixedThreadPool(16);
    static SimpleDateFormat dateFormat = new SimpleDateFormat("mm:ss");

    public static void main(String[] args) throws InterruptedException {
        for (int i = 0; i < 1000; i++) {
            int finalI = i;
            threadPool.submit(new Runnable() {
                @Override
                public void run() {
                    String date = new ThreadLocalDemo05().date(finalI);
                    System.out.println(date);
                }
            });
        }
        threadPool.shutdown();
    }

    public String date(int seconds) {
        Date date = new Date(1000 * seconds);
        String s = null;
        synchronized (ThreadLocalDemo05.class) {
            s = dateFormat.format(date);
        }
        return s;
    }
复制代码
```

这下好了，我们加上 synchronized 是没有重复了，但是效率大大降低了

那么有没有什么既可以吃西瓜又可以捡芝麻的方法呢？

可以**让每个线程都拥有一个自己的 simpleDateFormat 对象来达到这个目的**，这样就能两全其美了，说干就干

```java
public class ThreadLocalDemo06 {

    public static ExecutorService threadPool = Executors.newFixedThreadPool(16);

    public static void main(String[] args) throws InterruptedException {
        for (int i = 0; i < 1000; i++) {
            int finalI = i;
            threadPool.submit(new Runnable() {
                @Override
                public void run() {
                    String date = new ThreadLocalDemo06().date(finalI);
                    System.out.println(date);
                }
            });
        }
        threadPool.shutdown();
    }

    public String date(int seconds) {
        Date date = new Date(1000 * seconds);
        SimpleDateFormat dateFormat = ThreadSafeFormatter.dateFormatThreadLocal.get();
        return dateFormat.format(date);
    }
}

class ThreadSafeFormatter {
    public static ThreadLocal<SimpleDateFormat> dateFormatThreadLocal = new ThreadLocal<SimpleDateFormat>() {
        @Override
        protected SimpleDateFormat initialValue() {
            return new SimpleDateFormat("mm:ss");
        }
    };
}
复制代码
```

### 场景2

ok 场景2就是我们目前项目中使用到的，利用 ThreadLocal 来控制数据权限

我们想做到的是，每个线程内需要保存类似于全局变量的信息（例如在拦截器中获取的用户信息），可以让不同方法直接使用，避免参数传递的麻烦却不想被多线程共享（因为不同线程获取到的用户信息不一样）。

例如，用 ThreadLocal 保存一些业务内容，比如一个 UserRequest，这个 UserRequest中存放一些这个用户的信息，诸如权限组、编号等信息

在线程生命周期内，都通过这个静态 ThreadLocal 实例的 get() 方法取得自己 set 过的那个对象，避免了将这个request作为参数传递的麻烦

于是我们写了这样的一个工具类

```java
public class AppUserContextUtil {

    private static ThreadLocal<String> userRequest = new ThreadLocal<String>();

    /**
     * 获取userRequest
     *
     * @return
     */
    public static String getUserRequest() {
        return userRequest.get();
    }

    /**
     * 设置userRequest
     *
     * @param param
     */
    public static void setUserRequest(String param) {
        userRequest.set(param);
    }

    /**
     * 移除userRequest
     */
    public static void removeUserRequest() {
        userRequest.remove();
    }

}
复制代码
```

那么当一个请求进来的时候，一个线程会负责执行这个请求，无论这个请求经历过多少个类的方法的，都可以直接去 get 出我们的 userRequest 从而进行业务处理或者权限管控

## 在 Thread 中如何存储

二话不说，上图



一个 Thread 里面只有一个ThreadLocalMap ，而在一个 ThreadLocalMap 里面却可以有很多的 ThreadLocal，每一个 ThreadLocal 都对应一个 value。

因为一个 Thread 是可以调用多个 ThreadLocal 的，所以 Thread 内部就采用了 ThreadLocalMap 这样 Map 的数据结构来存放 ThreadLocal 和 value。

我们一起看下 ThreadLocalMap 这个内部类

```java
static class ThreadLocalMap {

    static class Entry extends WeakReference<ThreadLocal<?>> {
        /** The value associated with this ThreadLocal. */
        Object value;


        Entry(ThreadLocal<?> k, Object v) {
            super(k);
            value = v;
        }
    }
   private Entry[] table;
//...
}
复制代码
```

ThreadLocalMap 类是每个线程 Thread 类里面的一个成员变量，其中最重要的就是截取出的这段代码中的 Entry  内部类。在 ThreadLocalMap 中会有一个 Entry 类型的数组，名字叫 table。我们可以把 Entry 理解为一个  map，其键值对为：

- 键，当前的 ThreadLocal；
- 值，实际需要存储的变量，比如 user 用户对象或者 simpleDateFormat 对象等。

ThreadLocalMap 既然类似于 Map，所以就和 HashMap 一样，也会有包括 set、get、rehash、resize 等一系列标准操作。但是，虽然思路和 HashMap 是类似的，但是具体实现会有一些不同。

比如其中一个不同点就是，我们知道 HashMap 在面对 hash 冲突的时候，采用的是拉链法。

但是 ThreadLocalMap 解决 hash 冲突的方式是不一样的，它采用的是线性探测法。如果发生冲突，并不会用链表的形式往下链，而是会继续寻找下一个空的格子。这是 ThreadLocalMap 和 HashMap 在处理冲突时不一样的点

## 使用姿势

### Key泄漏

我们刚才介绍了 ThreadLocalMap，每一个 ThreadLocal 都有一个 ThreadLocalMap

尽管我们可能会这样操作  ThreadLocal instance = null ，将这个实例设置为 null，以为这样就可以高枕无忧了

然而，经过GC严谨的可达性的分析，尽管我们在业务代码中把 ThreadLocal 实例置为了 null，但是在 Thread 类中依然有这个引用链的存在。

GC 在垃圾回收的时候会进行可达性分析，它会发现这个 ThreadLocal 对象依然是可达的，所以对于这个 ThreadLocal  对象不会进行垃圾回收，这样的话就造成了内存泄漏的情况。从而导致 OOM，从而导致半夜告警，从而导致绩效325，从而辞职送外卖等等一系反应

Doug Lea 考虑到如此危险，所以 ThreadLocalMap 中的 Entry 继承了 WeakReference 弱引用，

```java
static class Entry extends WeakReference<ThreadLocal<?>> {

    /** The value associated with this ThreadLocal. */
    Object value;

    Entry(ThreadLocal<?> k, Object v) {

        super(k);
        value = v;
    }
}
复制代码
```

可以看到，这个 Entry 是 extends  WeakReference。弱引用的特点是，如果这个对象只被弱引用关联，而没有任何强引用关联，那么这个对象就可以被回收，所以弱引用不会阻止  GC。因此，这个弱引用的机制就避免了 ThreadLocal 的内存泄露问题。

### Value泄漏

我们认真思考，ThreadLocalMap 的每个 Entry 都是一个对 key 的弱引用，但是这个 Entry 包含了一个对 value 的强引用

强引用那就意味着在线程生命不结束的时候，我们这个变量永远存在我们的内存里

但是很有可能我们早就不需要这个变量了，Doug Lea 是个暖男，为我们考虑到了这个问题，在执行 ThreadLocal 的  set、remove、rehash 等方法时，它都会扫描 key 为 null 的 Entry，如果发现某个 Entry 的 key 为  null，则代表它所对应的 value 也没有作用了，所以它就会把对应的 value 置为 null，这样，value 对象就可以被正常回收了。

但是假设 ThreadLocal 已经不被使用了，那么实际上 set、remove、rehash  方法也不会被调用，与此同时，如果这个线程又一直存活、不终止的话，那么这个内存永远不会被GC掉，也就导致了 value 的内存泄漏，从而导致  OOM，从而导致半夜告警，从而导致绩效325，从而辞职送外卖等等一系反应

为了避免悲剧的发生，我们在使用完了 ThreadLocal 之后，我们应该手动去调用它的 remove 方法，目的是防止内存泄漏的发生。

```java
public void remove() {
    ThreadLocalMap m = getMap(Thread.currentThread());
    if (m != null)
        m.remove(this);
}
复制代码
```

remove 方法中，可以看出，它是先获取到 ThreadLocalMap 这个引用的，并且调用了它的 remove 方法。这里的 remove 方法可以把 key 所对应的 value 给清理掉，这样一来，value 就可以被 GC 回收了

## 小结

以上就是 《浅谈 ThreadLocal 的实际运用 》的全部内容了，在本文中我们介绍了 ThreadLocal  的适用场景，并且针对场景进行了代码演示；认识了 ThreadLocal 在线程中究竟是如何存储的；也学会了使用 ThreadLocal  的正确姿势。

如果本文对你有帮助，欢迎点赞、关注。🙏