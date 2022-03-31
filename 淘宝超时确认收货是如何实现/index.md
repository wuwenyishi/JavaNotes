



<div style="text-align: center;"></div>

<!-- more -->



<audio id="audio" controls="" preload="none">  <source id="mp3" src="https://cdn.jsdelivr.net/gh/wuwenyishi/shared@music/2022/03/31/143037.mp3">  
</audio>


> 原文链接：[淘宝超时确认收货 是 如何实现？](https://mp.weixin.qq.com/s/8MM2-_3KifMFS6SxV3zslw)



今天跟大家聊下定时任务，很多人都喜欢网购，选择商品、下单、付款，然后在家坐等拆包裹，很少有人主动去点 `确认收货`，那岂不是结束不了订单，卖家也收不到货款。

其实，平台早已想到这个问题，所以会有`定时任务`，我们只需要设定好 `目标执行时间`，到了时间后，系统会自动执行 `确认收货`。

接下来，我们来看下，常见的定时任务有哪些？



# 淘宝超时确认收货是如何实现

### 单点定时任务

**1、JDK原生**

自从JDK1.5之后，提供了`ScheduledExecutorService`代替`TimerTask`来执行定时任务，提供了不错的可靠性。

```java
public class SomeScheduledExecutorService {
    public static void main(String[] args) {
        // 创建任务队列，共 10 个线程
        ScheduledExecutorService scheduledExecutorService =
                Executors.newScheduledThreadPool(10);
        // 执行任务: 1秒 后开始执行，每 30秒 执行一次
        scheduledExecutorService.scheduleAtFixedRate(() -> {
            System.out.println("执行任务：" + new Date());
        }, 10, 30, TimeUnit.SECONDS);
    }
}
```

**2、Spring Task**

Spring Framework自带定时任务，提供了cron表达式来实现丰富定时任务配置。

新手推荐使用https://cron.qqe2.com/这个网站来匹配你的`cron表达式`

```java
@Configuration
@EnableScheduling
public class SomeJob {
    private static final Logger LOGGER = LoggerFactory.getLogger(SomeJob.class);

    /**
     * 每分钟执行一次（例：18:01:00，18:02:00）
     * 秒 分钟 小时 日 月 星期 年
     */
    @Scheduled(cron = "0 0/1 * * * ? *")
    public void someTask() {
       //...
    }
}
```

单点的定时服务在目前微服务的大环境下，应用场景越来越局限，所以尝鲜一下分布式定时任务吧。

**3、基于 Redis 实现**

相较于之前两种方式，这种基于Redis的实现可以通过多点来增加定时任务，多点消费。但是要做好防范重复消费的准备。

**3.1 通过ZSet的方式**

将定时任务存放到ZSet集合中，并且将过期时间存储到ZSet的Score字段中，然后通过一个循环来判断当前时间内是否有需要执行的定时任务，如果有则进行执行。

具体实现代码如下：

```java
@Configuration
@EnableScheduling
public class RedisJob {
    public static final String JOB_KEY = "redis.job.task";
    private static final Logger LOGGER = LoggerFactory.getLogger(RedisJob.class);
    @Autowired private StringRedisTemplate stringRedisTemplate;

    /**
     * 添加任务.
     *
     * @param task
     */
    public void addTask(String task, Instant instant) {
        stringRedisTemplate.opsForZSet().add(JOB_KEY, task, instant.getEpochSecond());
    }

    /**
     * 定时任务队列消费
     * 每分钟消费一次（可以缩短间隔到1s）
     */
    @Scheduled(cron = "0 0/1 * * * ? *")
    public void doDelayQueue() {
        long nowSecond = Instant.now().getEpochSecond();
        // 查询当前时间的所有任务
        Set<String> strings = stringRedisTemplate.opsForZSet().range(JOB_KEY, 0, nowSecond);
        for (String task : strings) {
            // 开始消费 task
            LOGGER.info("执行任务:{}", task);
        }
        // 删除已经执行的任务
        stringRedisTemplate.opsForZSet().remove(JOB_KEY, 0, nowSecond);
    }
}
```

**适用场景如下：**

- 订单下单之后15分钟后，用户如果没有付钱，系统需要自动取消订单。
- 红包24小时未被查收，需要延迟执退还业务；
- 某个活动指定在某个时间内生效&失效；

**优势是：**

- 省去了MySQL的查询操作，而使用性能更高的Redis做为代替；
- 不会因为停机等原因，遗漏要执行的任务；

**3.2 键空间通知的方式**

我们可以通过Redis的键空间通知来实现定时任务，它的实现思路是给所有的定时任务设置一个过期时间，等到了过期之后，我们通过订阅过期消息就能感知到定时任务需要被执行了，此时我们执行定时任务即可。

默认情况下Redis是不开启键空间通知的，需要我们通过`config set notify-keyspace-events Ex`的命令手动开启。开启之后定时任务的代码如下:

自定义监听器

```java
public class KeyExpiredListener extends KeyExpirationEventMessageListener {
    public KeyExpiredListener(RedisMessageListenerContainer listenerContainer) {
        super(listenerContainer);
    }

    @Override
    public void onMessage(Message message, byte[] pattern) {
        // channel
        String channel = new String(message.getChannel(), StandardCharsets.UTF_8);
        // 过期的key
        String key = new String(message.getBody(), StandardCharsets.UTF_8);
        // todo 你的处理
    }
}
```

设置该监听器

```java
@Configuration
public class RedisExJob {
    @Autowired private RedisConnectionFactory redisConnectionFactory;
    @Bean
    public RedisMessageListenerContainer redisMessageListenerContainer() {
        RedisMessageListenerContainer redisMessageListenerContainer = new RedisMessageListenerContainer();
        redisMessageListenerContainer.setConnectionFactory(redisConnectionFactory);
        return redisMessageListenerContainer;
    }

    @Bean
    public KeyExpiredListener keyExpiredListener() {
        return new KeyExpiredListener(this.redisMessageListenerContainer());
    }
}
```

Spring会监听符合以下格式的Redis消息

```
private static final Topic TOPIC_ALL_KEYEVENTS = new PatternTopic("__keyevent@*");
```

基于Redis的定时任务能够适用的场景也比较有限，但实现上相对简单，但对于功能幂等有很大要求。从使用场景上来说，更应该叫做延时任务。

**场景举例:**

- 订单下单之后15分钟后，用户如果没有付钱，系统需要自动取消订单。
- 红包24小时未被查收，需要延迟执退还业务；

**优劣势是：**

- 被动触发，对于服务的资源消耗更小；
- Redis的Pub/Sub不可靠，没有ACK机制等，但是一般情况可以容忍；
- 键空间通知功能会耗费一些CPU

### 分布式定时任务

> 引入分布式定时任务组件or中间件

将定时任务作为单独的服务，遏制了重复消费，独立的服务也有利于扩展和维护。

**1、quartz**

依赖于MySQL，使用相对简单，可多节点部署，通过竞争数据库锁来保证只有一个节点执行任务。没有图形化管理页面，使用相对麻烦。

**2、elastic-job-lite**

依赖于Zookeeper，通过zookeeper的注册与发现，可以动态的添加服务器。

- 多种作业模式
- 失效转移
- 运行状态收集
- 多线程处理数据
- 幂等性
- 容错处理
- 支持spring命名空间
- 有图形化管理页面

**3、LTS**

依赖于Zookeeper，集群部署,可以动态的添加服务器。可以手动增加定时任务，启动和暂停任务。

- 业务日志记录器
- SPI扩展支持
- 故障转移
- 节点监控
- 多样化任务执行结果支持
- FailStore容错
- 动态扩容
- 对spring相对友好
- 有监控和管理图形化界面

**4、xxl-job**

国产，依赖于MySQL,基于竞争数据库锁保证只有一个节点执行任务，支持水平扩容。可以手动增加定时任务，启动和暂停任务。

- 弹性扩容
- 分片广播
- 故障转移
- Rolling实时日志
- GLUE（支持在线编辑代码，免发布）
- 任务进度监控
- 任务依赖
- 数据加密
- 邮件报警
- 运行报表
- 优雅停机
- 国际化（中文友好）

### 总结

微服务下，推荐使用xxl-job这一类组件服务将定时任务合理有效的管理起来。而单点的定时任务有其局限性，适用于规模较小、对未来扩展要求不高的服务。

相对而言，基于spring task的定时任务最简单快捷，而xxl-job的难度主要体现在集成和调试上。无论是什么样的定时任务，你都需要确保：

- 任务不会因为集群部署而被多次执行。
- 任务发生异常得到有效的处理
- 任务的处理过慢导致大量积压
- 任务应该在预期的时间点执行

中间件可以将服务解耦，但增加了复杂度