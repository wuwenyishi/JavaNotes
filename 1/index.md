# Dubbo是如何基于动态代理实现RPC调用的？                         

![Dubbo是如何基于动态代理实现RPC调用的？](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2111-FgcJ5Y.awebp)

#### 目录

- 啥叫分布式系统？
- 分布式系统之间如何调用呢？
- Dubbo是如何基于动态代理实现RPC调用的？
- 总结

今天给大家讲一个知识点，就是我们平时很多兄弟现在开发系统都不是那种10年前的简单单块系统了，一个工程打包部署启动，系统连接MySQL，然后crud整起就够的了，我们开发的系统都是很高大上的分布式系统。

#### 啥叫分布式系统？

就是说你写的系统收到一个请求之后，你自己的代码跑完还不够，你得**去调用别的兄弟写的系统**，让他的系统也干一些事儿，然后他的活儿也干完了之后，你这次请求处理才算是完事儿了，就因为你处理请求得调用别的兄弟系统一起运行，一个请求涉及到了分布在多台机器上的多个系统，所以就叫做分布式了，如下图。

  ![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2110-Eymv0A.awebp)

#### 分布式系统之间如何调用呢？

那现在兄弟们平时开发分布式系统，就是去调用别的系统，一般都是用什么框架呢？简单，现在兄弟们一般都是用**spring cloud**，或者是用**dubbo**，这两种都有人用，用spring cloud的一般前两年多一些，最近这两年大家都纷纷转用spring cloud alibaba了。

以前用spring cloud的时候，你要调用别的系统一般用的是**feign**这个框架，然后现在你用spring cloud alibaba的时候，一般用的都是**dubbo**这个框架，我们今天就以**dubbo**这个框架举例来讲讲我们平时系统之间是如何进行调用的。

首先呢，我们还是看上面那个图里的业务系统B，这个系统如果要提供接口给别人调用，那么他必须写一个接口，这个接口里得定义好你要允许别人调用哪些方法，大致看起来可能类似下面这样的代码，如下：

```java
public interface Service {  
    String sayHello(String name);   
}

接着呢，你得针对这个接口开发一个实现类，实现类里需要完成这个方法的逻辑，同时还得给这个实现类加上@DubboService这个注解，让Dubbo把他识别为一个对外的服务接口，如下面的代码：
@DubboService(version = "1.0.0", interfaceClass = Service.class)
public class ServiceImpl implements Service {    
    public String sayHello(String name) {   
        // 运行一些代码    
      return "hello, " + name;   }  

}
复制代码
```

那么当你的业务系统B开发好上面的接口和实现类，同时加上了**@DubboService**这个注解之后，这个业务系统B启动以后，**会干一个什么事儿呢？\**简单来说，Dubbo框架会随着你的业务系统B一起启动，他会启动一个网络服务器，这个网络服务器会监听一个你指定的端口号，通常这个端口号是\**20880**端口，如下图。

  ![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2111-BqrlNu.awebp)

这个时候业务系统B上的dubbo已经启动好了网络服务器**监听了一个端口号**，随时可以接收你发送过来的调用请求，接下来就轮到咱们的业务系统A出场了，这个业务系统A假设要调用业务系统B的Service接口中定义的那些方法，他会怎么做呢？这个代码大概会是这样的：

```java
@RestController 
public class Controller {  
    // 注意，这里的Service就是业务系统B定义的接口 	
    @DubboReference(version = "1.0.0")  
    private Service service;    
    
   
    @RequestMapping("/hello")  
    public Response sayHello(String name) {          
        String result = service.sayHello(name);    
        return Response.success(result);   }    
}
复制代码
```

所以说，这里最关键的问题来了，上面是业务系统A的代码，他仅仅是定义了一个业务系统B的Service接口的变量，就是Service  service这个变量，然后加了一个**@DubboReference**注解，所以这个业务系统A启动的时候，Dubbo又会干点什么事儿呢？

#### Dubbo是如何基于动态代理实现RPC调用的

其实这里有一个很重点的点，那就是Dubbo此时会使用我们设计模式里的**代理模式**，去创建一个动态代理对象，把这个动态代理对象注入给我们上面的Service service这个变量，让他那个变量引用**Dubbo的动态代理对象**。

那么这个动态代理对象是个什么东西呢？简单来说，就是Dubbo可以动态生成一个类，这个类是实现了Service接口的，然后所有的方法都是有他自己的一套实现逻辑的，具体什么实现逻辑一会儿我们再说，但是现在看起来应该如下图。

  ![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2111-IRtbu7.awebp)

所以这里其实很关键的一点是，大家一定要在这里理解这个Dubbo动态代理的概念，这是设计模式中代理模式一个很经典的运用，就是说，一旦Dubbo生成了针对接口的动态代理对象，注入给了Service service这个变量，那么你业务系统A里调用Service service的方法时，其实是会调用**Dubbo动态代理对象的方法**的，再看一下代码感受一下：

```java
@RestController 
public class Controller {     
    
    // 注意，这里的Service就是业务系统B定义的接口   
    // 这个接口变量其实会被注入Dubbo生成的动态代理对象 	
    @DubboReference(version = "1.0.0")   
    private Service service;   
    
    @RequestMapping("/hello")   
    public Response sayHello(String name) { 
        // 注意，这里你调用接口方法的时候，其实是在调用Dubbo动态代理对象的方法   
        String result = service.sayHello(name);    
     return Response.success(result);
    }  
    
}
复制代码
```

**接着Dubbo动态代理对象的方法被调用的时候，他会干什么事情呢？**  其实这里他就会跟我们的业务系统B所在的机器建立一个网络连接，然后通过这个网络连接把一个调用请求发送过去，业务系统B里面的Dubbo网络服务器收到请求之后，就会根据请求调用本地的接口实现类的方法，拿到返回值，接着通过网络连接把返回值返回给业务系统A的dubbo动态代理对象，最后，dubbo动态代理对象就会把这个返回值交给我们了，如下图。

  ![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/02/2112-KrjoDa.awebp)

#### 总结

好了，今天给大家分享的基于dubbo实现系统间调用的原理就到这里了，希望大家平时用dubbo做开发的时候，对他底层的原理也得有一定的理解。