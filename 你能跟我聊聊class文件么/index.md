# 同事：你能跟我聊聊class文件么？





# 1.前言

上次在《[JAVA代码编译流程是怎样的？](http://mp.weixin.qq.com/s?__biz=MzAwNDA2OTM1Ng==&mid=2453156810&idx=1&sn=b8e7c90ea85775fbe91e2f5aaf0a9ead&chksm=8cfd1149bb8a985f6dbda9502006ff840c3ed5c54912fa41039016d4d0ee2ead90616f53c598&scene=21#wechat_redirect)》一文中已经聊过了**Java源码经过编译器的一系列转换最终生成标准的Class文件**的过程，我们用一张图来简单地回顾一下：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153011.png)

Java为了实现“一次编写，到处运行”的跨平台特性，选取了Class文件这一中间格式来保证代码能在不同平台运行。**Class文件中记录了源代码中类的字段、方法指令等重要信息。**

Class文件可以在不同平台上的不同JVM中运行，它们最终生成的机器指令可能也是有差别的，但是，最终执行的结果一定要保证各平台一致。

> 有一点值得注意的是，虽然Java是与平台无关的语言，但并不意味着Java虚拟机（JVM）是各平台通用的，不同的平台上运行的JVM是有一定区别的，它们为用户屏蔽了各平台的一些差异。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153018.png)

我们今天要聊的就是源代码和JVM中间的这一座桥梁——Class文件。

> 还有一件事，记得我们在《[JAVA代码编译流程是怎样的？](http://mp.weixin.qq.com/s?__biz=MzAwNDA2OTM1Ng==&mid=2453156810&idx=1&sn=b8e7c90ea85775fbe91e2f5aaf0a9ead&chksm=8cfd1149bb8a985f6dbda9502006ff840c3ed5c54912fa41039016d4d0ee2ead90616f53c598&scene=21#wechat_redirect)》一文的最后提到的 **字节码与Class文件的关系** 吗?
>
> 在本文中，需要再次强调，**字节码只是Class文件中众多组成部分的其中之一**。

# 2.如何阅读Class文件

Class文件的本质其实是一个十六进制的文件，所以其实可以直接用十六进制的编辑器打开Class文件。

如果这么做，则会看到如下的画面：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153026.jpeg)

这就是Class文件最质朴的模样，是不是看得直挠头，完全看不出跟源码的联系呀。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153033.png)

别急，今天就带大家把这块难啃的骨头一点一点都吸收消化了，保证大家看完后面的解析再回过头来看这串字符都会觉得眉清目秀的。

当然，工欲善其事，必先利其器。在学习开始之前，先介绍两个能够比较直观地查看Class文件的工具。

## 2.1 javap命令

`javap`是jdk中自带的支持解析Class文件的工具，通过`javap`命令，可以查看生成的Class文件的各个部分结构，先来个简单的例子：

```java
// 源代码
package com.cc.demo;
public class Hello {
    private final int a = 100;
    int b = 101;
    private final int c = 100;
    float d = 100f;
    public static void main(String[] args) {
        int e = 102;
    }
}
```

根据源代码生成Class文件之后，我们使用`javap`命令对其进行解析：

```java
ZMac-C1WM:demo aobing$ javap Hello.class
Compiled from "Hello.java"
public class com.cc.demo.Hello {
  public com.cc.demo.Hello();
  public static void main(java.lang.String[]);
}
```

这样得到的解析结果显然太过于简单了，**只显示了基本的类名、方法和参数等**，显然无法满足我们解析Class文件的实际需求。

> 在上述这个例子中，源码中本来没有编写任何的构造函数，但在生成的Class文件中，已经为我们加上了默认的无参构造器。
>
> 我们在上一篇《JAVA代码编译流程是怎样的？》中提过，添加默认无参构造器的行为是在填充符号表时完成的。

怎么说呢，看到这里，你大概觉得`javap`命令有点东西，但也没有很多东西。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153056.png)

其实因为我们出门没有忘记买装备了，没有发挥它真正的实力。

来，我们再次打开控制台，输入：

```
javap -help
```

然后就能见识到`javap`的完全体了：

```
ZMac-C1WM:~ aobing$ javap -help
用法: javap <options> <classes>
其中, 可能的选项包括:
  -help  --help  -?        输出此用法消息
  -version                 版本信息
  -v  -verbose             输出附加信息
  -l                       输出行号和本地变量表
  -public                  仅显示公共类和成员
  -protected               显示受保护的/公共类和成员
  -package                 显示程序包/受保护的/公共类
                           和成员 (默认)
  -p  -private             显示所有类和成员
  -c                       对代码进行反汇编
  -s                       输出内部类型签名
  -sysinfo                 显示正在处理的类的
                           系统信息 (路径, 大小, 日期, MD5 散列)
  -constants               显示最终常量
  -classpath <path>        指定查找用户类文件的位置
  -cp <path>               指定查找用户类文件的位置
  -bootclasspath <path>    覆盖引导类文件的位置
```

一般用的比较多的有两个：`-c`和`-v`。

先看一下`javap -c`的效果：

```
ZMac-C1WM:~ aobing$ javap -c  Hello.class
Compiled from "Hello.java"
public class com.cc.demo.Hello {
  int b;

  float d;

  public com.cc.demo.Hello();
    Code:
       0: aload_0
       1: invokespecial #1                  // Method java/lang/Object."<init>":()V
       4: aload_0
       5: bipush        100
       7: putfield      #2                  // Field a:I
      10: aload_0
      11: bipush        101
      13: putfield      #3                  // Field b:I
      16: aload_0
      17: bipush        100
      19: putfield      #4                  // Field c:I
      22: aload_0
      23: ldc           #5                  // float 100.0f
      25: putfield      #6                  // Field d:F
      28: return

  public static void main(java.lang.String[]);
    Code:
       0: bipush        102
       2: istore_1
       3: return
}
```

而`javap -v`的效果是这样的：

```
ZMac-C1WM:~ aobing$ javap -v Hello.class
Classfile /Users/aobing/src/com/cc/demo/Hello.class
  Last modified 2022-2-11; size 441 bytes
  Compiled from "Hello.java"
public class com.cc.demo.Hello
  minor version: 0
  major version: 52
  flags: ACC_PUBLIC, ACC_SUPER
Constant pool:
   #1 = Methodref          #8.#31         // java/lang/Object."<init>":()V
   #2 = Fieldref           #7.#32         // com/cc/demo/Hello.a:I
   #3 = Fieldref           #7.#33         // com/cc/demo/Hello.b:I
   #4 = Fieldref           #7.#34         // com/cc/demo/Hello.c:I
   #5 = Float              100.0f
   #6 = Fieldref           #7.#35         // com/cc/demo/Hello.d:F
   #7 = Class              #36            // com/cc/demo/Hello
   #8 = Class              #37            // java/lang/Object
   #9 = Utf8               a
  #10 = Utf8               I
  #11 = Utf8               ConstantValue
  #12 = Integer            100
  #13 = Utf8               b
  #14 = Utf8               c
  #15 = Utf8               d
  #16 = Utf8               F
  #17 = Utf8               <init>
  #18 = Utf8               ()V
  #19 = Utf8               Code
  #20 = Utf8               LineNumberTable
  #21 = Utf8               LocalVariableTable
  #22 = Utf8               this
  #23 = Utf8               Lcom/cc/demo/Hello;
  #24 = Utf8               main
  #25 = Utf8               ([Ljava/lang/String;)V
  #26 = Utf8               args
  #27 = Utf8               [Ljava/lang/String;
  #28 = Utf8               e
  #29 = Utf8               SourceFile
  #30 = Utf8               Hello.java
  #31 = NameAndType        #17:#18        // "<init>":()V
  #32 = NameAndType        #9:#10         // a:I
  #33 = NameAndType        #13:#10        // b:I
  #34 = NameAndType        #14:#10        // c:I
  #35 = NameAndType        #15:#16        // d:F
  #36 = Utf8               com/cc/demo/Hello
  #37 = Utf8               java/lang/Object
{
  int b;
    descriptor: I
    flags:

  float d;
    descriptor: F
    flags:

  public com.cc.demo.Hello();
    descriptor: ()V
    flags: ACC_PUBLIC
    Code:
      stack=2, locals=1, args_size=1
         0: aload_0
         1: invokespecial #1                  // Method java/lang/Object."<init>":()V
         4: aload_0
         5: bipush        100
         7: putfield      #2                  // Field a:I
        10: aload_0
        11: bipush        101
        13: putfield      #3                  // Field b:I
        16: aload_0
        17: bipush        100
        19: putfield      #4                  // Field c:I
        22: aload_0
        23: ldc           #5                  // float 100.0f
        25: putfield      #6                  // Field d:F
        28: return
      LineNumberTable:
        line 2: 0
        line 3: 4
        line 4: 10
        line 5: 16
        line 6: 22
      LocalVariableTable:
        Start  Length  Slot  Name   Signature
            0      29     0  this   Lcom/cc/demo/Hello;

  public static void main(java.lang.String[]);
    descriptor: ([Ljava/lang/String;)V
    flags: ACC_PUBLIC, ACC_STATIC
    Code:
      stack=1, locals=2, args_size=1
         0: bipush        102
         2: istore_1
         3: return
      LineNumberTable:
        line 8: 0
        line 9: 3
      LocalVariableTable:
        Start  Length  Slot  Name   Signature
            0       4     0  args   [Ljava/lang/String;
            3       1     1     e   I
}
SourceFile: "Hello.java"
```

这下东西是不是就多了起来呢，我们简单的对比一下`javap -c`和`javap -v`这两个命令的区别：

1. `javap -c`命令得到的信息包括类的字段及方法名称，还有一部分就是我们最常说的**字节码**，记录的是方法中的一系列操作指令。
2. `javap -v`命令得到的信息较为丰富不仅包含了字段和方法的具体信息（当然也包含了字节码），还包括了LineNumberTable和Constant Pool等Class文件中的详细信息。
3. 有时候这两个命令会与`-p`参数结合使用，例如：`javap -p -v`或者`javap -p -c`，目的是显示所有类和成员，把private修饰的部分也展示出来。

> tips：如果想使用`javap -v`命令看到局部变量表`LocalVariableTable`，那么需要在Javac编译的时候就指定参数生成局部变量表，即在`javac`的时候加上参数`-g:vars`。
>
> 如果直接使用`javac xx.java`最终生成的字节码中只有`LineNumberTable`信息，要用`javac -g:vars xx.java`命令来进行编译，再使用`javap -v`命令就可以看到局部变量表信息了。

## 2.2 jclasslib Bytecode Viewer

关于查看Class文件的工具，网上有很多功能相似的产品，例如国外团队写的Java-Class-Viewer工具以及国内大神写的开源的 Classpy、ClassViewer等工具，它们都是非常不错的Class文件分析工具，但是种种原因导致这些项目最终都停止更新，不再维护。

我们主要还是抱着学习的目的，了解一下Class文件的结构。那么工具的易用性就很重要了，我们希望有一个简单易用的工具，不用折腾太多乱七八糟的配置，可以让我们秉持拿来主义，直接就能上手。

这里推荐的是IDEA里的插件`jclasslib Bytecode Viewer`，直接在plugins里面安装一下就好啦。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153107.png)

这个插件还是不错的，免费，且简单易用，最重要的是可以直接在IDEA中对照着源码看字节码，使用感非常的nice~

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153121.png)

对于这个工具的具体用法我们就不过多赘述，多点几下差不多就会了，重点还是后面的Class文件解析的部分。

# 3. Class文件结构概述

**Class文件中的数据项按顺序存储在class文件中，相邻的项之间没有任何间隔，这样可以使得class文件紧凑且便于解析。**

前面提到的Class文件解析的工具基本也都是根据这一特性开发的。**因为Class文件中各个部分的顺序完全固定，只要知道各个部分占用空间的大小，按照顺序规范进行读取，就可以完成对Class文件的解析。**

Class文件主要分为以下几个部分：

1. 魔数（magic number）
2. 版本号（minor&major version）
3. 常量池（constant pool）
4. 访问标记（access flag）
5. 类索引（this class）
6. 超类索引（super class）
7. 接口表索引（interface）
8. 字段表（field）
9. 方法表（method）
10. 属性表（attribute）

我们先看看class文件的基本结构：

```
classFile{
    u4 magic; 
    u2 minor_version;
    u2 major_version;
    u2 constant_pool_count;
    cp_info constant_pool[constant_pool_count-1];
    u2 access_flags;
    u2 this_class;
    u2 super_class;
    u2 interfaces_count;
    u2 interfaces[interfaces_count];
    u2 fields_count;
    field_info fields[fields_count];
    u2 methods_count;
    method_info methods[methods_count];
    u2 attributes_count;
    attribute_info attributes[attributes_count];
}
```

**Class文件中的基本类型是以占用字节数命名的简单数据结构**，例如，`u1`、`u2`、`u4`，`u8`三种数据结构分别表示占用1、2、4、8字节的无符号整数，还有一种稍复杂的数据结构则是表（table）。

在上面的结构示例中，可以看到，除了`u1`、`u2`、`u4`之外的其他几个结构其实都是表，它们都以`_info`结尾，并以独特的名字标识自己的类型，例如方法表的类型就是`method_info`，常量池的类型就是`cp_info`（cp指的是constant pool）。

Class文件中table类型的另一个特征是 **紧跟着表数据之前会使用一个前置的容量计数器来记录表中元素的个数**，这样便于明确表的范围。例如`constant_pool`就是紧跟着`constant_pool_count`出现的，`constant_pool_count`记录的是`constant_pool`的数据量大小。

**这个记录是很重要的，因为Class文件中没有特定的开始和结束符号，只能通过这个count计数器，才知道对应的表占用多少空间，应该在什么位置结束。**

## 3.1 魔数

识别一个文件的类型，最简单的办法就是识别其文件后缀，比如我们看到一个以`.png`为后缀的文件，我们马上就判断这是一个png图片文件，知道需要用图片浏览器将其打开。

但如果只通过文件名后缀来判断文件的真实格式，未免有些轻率了。比如，如果我们将`.png`文件的后缀改为`.class`，我们再用`javap`命令将其打开，会发生什么呢？

```
ZMac-C1WM:~ aobing$ ls
Hello.class Hello.java pngTest.class
ZMac-C1WM:~ aobing$ javap pngTest.class 
错误: 读取pngTest.class时出现意外的文件结尾 
```

会由于格式错误无法打开。

在读取Class文件时，最开始需要做的就是校验魔数是否正确，如果加载的Class文件不符合Java规范，那么就会抛出`java.lang.ClassFormatError`的异常。

魔数用于对文件格式的二次校验，是判别文件格式的特殊标识，一般位于文件的开头位置，魔数本身没有什么限制，是可以由开发者自由定义的，只要保证不与其他文件格式的魔数重复。

魔数不是Class文件的专属，其他各类文件格式一般都定义了属于自己的魔数，比如png文件的魔数是`89 50 4E 47`(十六进制)，而Java的Class文件对应的魔数则是`CA FE BA BE`(十六进制)。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153131.png)

还记得Java的图标吗，一杯咖啡，

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153137.png)

而Class文件中的魔数`CA FE BA BE`，既是对Java语言本身logo的呼应，也是一种专属于Java的别样浪漫。

> 至于为什么是CAFEBABE而不是CAFEBABY，那大概就是因为十六进制中没有Y这个字母吧。

加载Class文件时，最先需要做的就是检查开头的四个字节，如果这四个字节不是CAFEBABE，则直接抛出错误，不用做后续的操作。

## 3.2 版本号

紧跟魔数的后面四个字节就是版本号啦，版本号由副版本号（minor_version）+主版本号（major_version）构成（副版本号在前），比如用JDK8环境编译好的Class文件中，版本号展示如下：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153144.png)

十六进制的`00 00 00 34`对应的十进制数字就是52，也就是说JDK8所对应的Class版本就是52，更多的版本对应如下图所示：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153151.png)

有时候运行代码提示JDK版本问题，就是在这一步检测到Class文件的版本号与当前的运行环境不一致。

> 只有jdk 1.1版本的副版本号为`00 03`，后续的版本都是副版本为`00 00`，而且除1.1版本外，后续每次发布新版本时只变动主版本号，主版本号每次加1。

## 3.3 常量池

紧随版本号之后的部分是常量池，这一部分在Class文件中占比很高，也是Class文件中最复杂，最重要的部分之一。

在Java代码中，如果涉及到一些数字的操作，需要用到各类的指令。对于占用字节比较少的整数类型，这些简单数字的操作被枚举成了具体的指令，嵌入到了字节码中（后续会进行讲解）。

**但对于一些比较大的数字（主要是那些无法用4个字节表示的类型，例如float、double等类型）**，则会被记录在常量池中，当需要使用这些操作数的时候，会根据索引值到常量池中来查取。

Class文件中，**常量池是以表的形式存在的，因此它的前置还有一个用以表示常量池表大小的计数器**，常量池整体的结构可以表示为：

```
{
    u2 constant_pool_count;
    cp_info constant_pool[constant_pool_count-1];
}
```

`constant_pool`的索引从1开始，但count计数的时候会把0的位置也记录数上，也就是说，**如果`constant_pool_count=5`，那么`constant_pool`数组的有效索引为[1]-[4]，而不是[0]-[4]。**

**另外值得一提的一点是，long类型与double类型的数据在cp_info中会占用两个索引的位置，因此`constant_pool`中的元素个数可能比`cp_info_count`的索引指示地要少。**

`constant_pool`中每一个`cp_info`元素又可分为两个部分：

1. tag：通常为1个字节，用于表示该常量项的类型；
2. info：该常量项的具体内容，根据不同类型的实际数据占用不同的字节长度；

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153159.png)

目前Java中总共支持14种tag，命名的规则是：`CONSTANT_XXX_info`，其中XXX是具体的常量类型，可以是Integer、Float、String等。具体如下：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153206.png)

这里面东西比较多，我们挑一个有代表性的来讲讲，我们还是以开头那段代码为例：

```
package com.cc.demo;
public class Hello {
    private final int a = 100;
    int b = 101;
    private final int c = 100;
    float d = 100f;
    public static void main(String[] args) {
        int e = 102;
    }
}
```

编译好之后，我们用`javap -p -v`命令解析其对应的Class文件，同时在IDEA中将jclasslib打开。`javap -p -v Hello.class`的结果如下（加入`-p`参数是为了将`private`修饰的字段解析出来）：

由于下面这个内容还会用到很多次，我们暂且将其命名为 **例子1**：

```
public class com.cc.demo.Hello
  minor version: 0
  major version: 52
  flags: ACC_PUBLIC, ACC_SUPER
Constant pool:
   #1 = Methodref          #8.#31         // java/lang/Object."<init>":()V
   #2 = Fieldref           #7.#32         // com/cc/demo/Hello.a:I
   #3 = Fieldref           #7.#33         // com/cc/demo/Hello.b:I
   #4 = Fieldref           #7.#34         // com/cc/demo/Hello.c:I
   #5 = Float              100.0f
   #6 = Fieldref           #7.#35         // com/cc/demo/Hello.d:F
   #7 = Class              #36            // com/cc/demo/Hello
   #8 = Class              #37            // java/lang/Object
   #9 = Utf8               a
  #10 = Utf8               I
  #11 = Utf8               ConstantValue
  #12 = Integer            100
  #13 = Utf8               b
  #14 = Utf8               c
  #15 = Utf8               d
  #16 = Utf8               F
  #17 = Utf8               <init>
  #18 = Utf8               ()V
  #19 = Utf8               Code
  #20 = Utf8               LineNumberTable
  #21 = Utf8               LocalVariableTable
  #22 = Utf8               this
  #23 = Utf8               Lcom/cc/demo/Hello;
  #24 = Utf8               main
  #25 = Utf8               ([Ljava/lang/String;)V
  #26 = Utf8               args
  #27 = Utf8               [Ljava/lang/String;
  #28 = Utf8               e
  #29 = Utf8               SourceFile
  #30 = Utf8               Hello.java
  #31 = NameAndType        #17:#18        // "<init>":()V
  #32 = NameAndType        #9:#10         // a:I
  #33 = NameAndType        #13:#10        // b:I
  #34 = NameAndType        #14:#10        // c:I
  #35 = NameAndType        #15:#16        // d:F
  #36 = Utf8               com/cc/demo/Hello
  #37 = Utf8               java/lang/Object
{
  private final int a;
    descriptor: I
    flags: ACC_PRIVATE, ACC_FINAL
    ConstantValue: int 100

  int b;
    descriptor: I
    flags:

  private final int c;
    descriptor: I
    flags: ACC_PRIVATE, ACC_FINAL
    ConstantValue: int 100

  float d;
    descriptor: F
    flags:

  public com.cc.demo.Hello();
    descriptor: ()V
    flags: ACC_PUBLIC
    Code:
      stack=2, locals=1, args_size=1
         0: aload_0
         1: invokespecial #1                  // Method java/lang/Object."<init>":()V
         4: aload_0
         5: bipush        100
         7: putfield      #2                  // Field a:I
        10: aload_0
        11: bipush        101
        13: putfield      #3                  // Field b:I
        16: aload_0
        17: bipush        100
        19: putfield      #4                  // Field c:I
        22: aload_0
        23: ldc           #5                  // float 100.0f
        25: putfield      #6                  // Field d:F
        28: return
      LineNumberTable:
        line 2: 0
        line 3: 4
        line 4: 10
        line 5: 16
        line 6: 22
      LocalVariableTable:
        Start  Length  Slot  Name   Signature
            0      29     0  this   Lcom/cc/demo/Hello;

  public static void main(java.lang.String[]);
    descriptor: ([Ljava/lang/String;)V
    flags: ACC_PUBLIC, ACC_STATIC
    Code:
      stack=1, locals=2, args_size=1
         0: bipush        102
         2: istore_1
         3: return
      LineNumberTable:
        line 8: 0
        line 9: 3
      LocalVariableTable:
        Start  Length  Slot  Name   Signature
            0       4     0  args   [Ljava/lang/String;
            3       1     1     e   I
}
SourceFile: "Hello.java"
```

可以看到，在常量池Constant Pool中，只有一个Integer类型的常量，也就是`#12 = Integer 100`。

前面说了，int类型占用的空间不超过4字节，按理来说是不会加入到常量池中的，而且在本类中`a`,`b`,`c`三个变量都是整型的，为什么只有值100被加入到了常量池，变量b的值101怎么没有加入到常量池中？

**这是由于当整型变量以final修饰时，它被声明为一个常量，此时才会加入常量池。**

而未被final修饰的整型变量（本例中的变量b = 101），其值101就不会被加入到常量池中。

但是像float和double这种类型，无论是否声明为final，都会被加入到常量池中。如本例中的`#5 = Float 100.0f`，就是变量`d`的值被加入到常量池中。

> 深层的原因我们在后面讲到第8部分字段表时，会详细解答。

其次同一个常量值不会被重复保存在常量池，例如本例子中的`a`和`c`都被final修饰，值都是100，当100这个值被加到常量池中后，变量`a`会指向该常量池的索引。

**然后变量`c`也被声明为常量的100，但此时，并不会将100的值在常量池中再保存一次，而是复用已经保存的常量值100，也就是说`a`和`c`指向常量池中的同一个索引位置。**

这一点我们可以从jclasslib得到答案：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153217.png)

可以看到`a`和`c`的常量值对象都指向`cp_info #12`，证明它们复用了同一个常量值。

我们根据已有信息来一次反推，十进制的100对应的是十六进制的64，这点我们从jclasslib中也可以得到一致的信息。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153224.png)

我们前面讲过，`CONSTANT_Integer_info`的`tag`是3，然后接的是四个字节的常量信息，表示用十六进制表示的常量值100，占用四个字节的空间，也就是`00 00 00 64`。

因此我们期待以十六进制方式打开Class文件后能够得到`final int a = 100`以`03 00 00 00 64`这样的内容保存着（变量名可任意）。

事实是怎么样的呢，如下：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153233.png)

没错，这就是Class文件将100这个值保存在常量池中的样子。

你学会了吗。

## 3.4 访问标记

等到常量池的部分结束后，紧随其后的就是访问标记了。访问标记其实很好理解，就是类上的修饰符，如final、abstract等。

这个部分用两个字节的空间来保存，其实这里十六进制值存储的也是约定好的枚举值，不同的枚举值对应不同的访问标记名：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153246.png)

在上面这个例子1中，访问标记就是`00 21`：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153252.png)

`00 21`对应的就是`ACC_PUBLIC`以及`ACC_SUPER`，意味着这个类是public修饰的类，而`ACC_SUPER`则代表该类有继承关系。这也很好理解，在Java中，所有的类都是Object类的子类嘛。

## 3.5 类索引（this_class）

顾名思义，**类索引保存的是一个与类相关的索引，既然有索引那么肯定有数据，那么它指向的数据是哪呢，就是前面提到的常量池**。

在例1中，类索引紧跟访问标记`00 21`之后，也就是对应的`00 07`，指向常量池中索引为7的位置：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153304.png)

我们找到常量池中索引为7的位置，发现这个位置对应的其实是一个`CONSTANT_Class_info`，代表这是一个类的信息常量：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153314.png)

类对应的类名是`cp_info #36`，我们继续找下去，可以看到，this_class最终指向的是一个字符串字面量，也就是本类的类名：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153320.png)

## 3.6 超类索引（super_name）

与类索引的查询方法一致，在例子1中，对应的超类索引十六进制值为`00 08`：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153336.png)

同样到常量池中取索引，得到最终的超类名为：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153349.png)

所有的类都是Object类的子类，在这一步得到了验证。

## 3.7 接口索引（interface）

与前两个索引的查询方法一致，不过这里有一些特殊点，在例子1中，由于该类没有实现任何接口，所以接口表索引为`00 00`：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153354.png)

还记得前面所说的**常量池的索引从1开始，而0号位是无效位**吗？

将0号位置设为无效就是为了应对这种情况。

**由于常量池中没有0号索引位，因此读取到`00 00`这样的索引时可知，此索引表示的是 不存在该信息。**

## 3.8 字段表

接口索引之后紧跟的是字段表，字段表很好理解啦，记录的就是类中的字段信息。前面已经说过，Class文件中的表的结构，都是以 **表大小+表内容** 来表示的，字段表当然也不例外，它的表示为：

```
{
    u2 fields_count;
    field_info fields[fields_count];
}
```

`fields_count`表示的是`fields`中的`field_info`数量。

字段内容`field_info`内部又可以细分为：

```
{
    u2 access_flags;
    u2 name_index;
    u2 descriptor_index;
    u2 attributes_count;
    attribute_info attributes[attributes_count];
}
```

我们来简单介绍一下这几个部分的内容：

### 3.8.1 access_flags

访问标记。这跟类的访问标记相似，只不过字段表中的访问标记存储的是字段上的public、private、protected等信息，当然也包括static、final等声明信息，同样是以枚举的方式记录：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153411.png)

### 3.8.2 name_index

字段名索引。跟3.5中的类索引相似，`name_index`记录的是常量池中的索引，最终可以通过`name_index`找到一个字符串常量名，也就是字段名。

比如，在例子1中，第一个字段的`name_index`如下：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153417.png)

再到常量池索引为`#9`的位置查找，最终得到的字段名就是`a`啦。

### 3.8.3 descriptor_index

字段类型索引。

跟字段名索引的功能类似，指向常量池中的一个字符串常量，但是为了节省空间，字段的类型是用简写方式表示的，例如：

1. 基础类型，byte、int、char、float等这些简单类型使用一个大写字符来表示，B对应byte类型，I对应的是Integer，**大部分类型对应都是自己本身的首字母大写，除了有两个特殊的——J对应的是long类型，Z表示boolean类型**。
2. **引用类型使用L+全类名+；的方式来表示**，为了防止多个连续的引用类型描述符出现混淆，引用类型描述符最后都加了一个分号";"作为结束，比如字符串类型String的描述符为`Ljava/lang/String;`。
3. **数组类型用"["来表示**，如字符串数组String[]的描述符为“`[Ljava/lang/String;`”，同时该符号也可表示多维数组，如`int[][]`就被表示为`[[I`。

在例子1中，变量a的`descriptor_index`为`00 0A`，也就是指向索引`#10`的位置，最终找到变量a的类型为`I`，也就是Integer。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153427.png)

### 3.8.4 attributes_count与attributes（属性表）

`attributes_count`表示的是字段属性项个数，而`attributes`则是字段属性项集合。

`attributes`中由各类的`attribute_info`组成，`attribute_info`记录的是具体的属性信息，比较常见的有`ConstantValue`属性，表示这个字段是一个常量；还有`RuntimeVisibleAnnotations`属性，表示该字段上标注有运行时注解，比如Spring相关注解。

> 关于运行时注解与编译时注解我们在编译过程中已经讨论过了，还有疑惑的同学可以回过去复习一下。

可以发现，字段表其实是一个**嵌套式**的表结构，`field_info`表内部嵌套一个`attributes`。

我们回到Class文件中看看他们是怎么表示的，在例子1`javap`结果中间的部分，在`#37`之后的一行，有关于变量`a`的描述：

```
private final int a;
    descriptor: I
    flags: ACC_PRIVATE, ACC_FINAL
    ConstantValue: int 100
```

这里展示的就是变量`a`对应的`访问标记`、`字段类型`以及`属性表`的内容啦。

在jclasslib中就看得更清楚了：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153434.png)

这就是字段表中保存的关于变量a的相关信息了。

**等等，这里有一个重点！！**

我们在**3.3 常量池**的部分中抛出了一个问题，**为什么int类型字段值只有声明为final后才会被保存到常量池中？**

这里就能得到答案。

因为声明为final的字段，需要在`attribute_info`中存储`ConstantValue`属性来标识该字段是一个常量。而`ConstantValue`又需要记录下该字段的值。

这个值保存在哪个地方最适合呢，当然是常量池啦。

我们使用jclasslib查看就更直观了，常量值的索引指向`cp_info #12`，而常量池中`#12`位置存储的正是值`100`。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153441.png)

> 未被final声明的int类型，其值不会保存到常量池中，而是在使用时直接嵌入到字节码中，如本例子中的变量b：
>
> ![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153447.png)

## 3.9 方法表

方法表的作用和字段表很类似，用于记录类中定义的方法。

当然，方法表前也是有一个count记录的，具体的结构如下：

```
{
  u2    methods_count;
  method_info    methods[methods_count];
}
```

`method_info`也是一个嵌套结构：

```
{
  u2    access_flags;
  u2    name_index;
  u2    descriptor_index;
  u2    attributes_count;
  attribute_info  attributes[attributes_count];
}
```

前四个部分就不用介绍了，跟字段表中的信息基本一致，描述的是一些方法声明信息。

**我们直接来聊聊方法表中的这个`attribute_info`，也就是方法中的属性表。**

字段中的属性表存储了字段的常量值等信息，而通常来说，方法的定义是要比字段定义稍微复杂一些的，比如方法有方法体，有声明的抛出异常等，而这些信息，就都存储在方法表里的`attribute_info`里。因此方法中可用的`attribute_info`要更多。

例如方法体对应的属性是`Code`，而异常信息对应的属性名为`Exceptions`，这都是字段中不存在的属性。

在方法表的属性表中，最为重要的就是`Code`属性，例如例子1中的main方法，其`Code`属性在字节码中是这样表示的：

```
Code:
      stack=1, locals=2, args_size=1
         0: bipush        102
         2: istore_1
         3: return
      LineNumberTable:
        line 8: 0
        line 9: 3
      LocalVariableTable:
        Start  Length  Slot  Name   Signature
            0       4     0  args   [Ljava/lang/String;
            3       1     1     e   I
```

其中最重要的部分，在这：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/153504.png)

这一部分就是我们俗称的 **字节码**。

开篇我们就强调了，**字节码是Class文件的一部分**，但它究竟在什么位置，现在就有了答案：

**字节码记录在Class文件的方法表中的attribute_info的Code属性里**。

> 这里暂时不展开讲Code部分，各位同学不要心急，后续会单独写一篇字节码相关的文章，保证给大家安排地明明白白。

至于stack（操作数栈），locals（局部变量），LineNumberTable（行号表）和LocalVariableTable（局部变量表），都是JVM运行时需要相关的信息，我们可以暂时不用纠结，后续也会接触到的。

**现在大家只要记住字节码其实保存在方法表中就可以了。**

## 3.10 属性表

是不是很眼熟？**属性表在前面已经出现过了，在字段表中、方法表中，都内嵌了一个属性表。**

**而这里的属性表，记录的是该类的类属性**（注意不是类字段），它的结构如下：

```
{
  u2    attributes_count;
  attribute_info attributes[attributes_count];
}
```

`attribute_info`的具体结构又可细分：

```
{
  u2 attribute_name_index;
  u4 attribute_length;
  u1 info[attribute_length];
}
```

所以说啊，**类中有一个属性表，方法中有一个属性表，字段中还是有一个属性表**，但它们记录的东西不一样：

- **字段表中的属性表**记录的是字段是否为常量、字段上是否有注解等信息。
- **方法表中的属性表**记录了方法上是否有注解、方法的异常信息声明、字节码等信息。

同样的，不同位置的属性表可供使用的属性也不一样，比如`ConstantValue`不能用在类和方法上，`Exceptions`属性不能用在字段上。

那Class文件最后的这个属性表记录的跟类的相关信息具体有哪些呢？

只说几个常见的：

1. SourceFile：类的源文件名称。
2. RuntimeVisibleAnnotations：类上标记的注解信息。
3. InnerClasses：记录类中的内部类。

属性表的规则相比于其他的部分较为松散一些，第一，属性表中的属性并没有顺序要求，第二，不同的属性内部的具体的info内容结构也是各异的，**需要按照虚拟机的规范事先约定好，虚拟机读取到对应的属性名称后，再按规范去解析其中的属性信息**。

我们举一个例子，在方法表的属性表中（有点像绕口令哈哈），可能会存在`LineNumberTable`和`Exceptions`两种属性，虽然它们的开头部分是一致的：**一个占用两字节的`attribute_name_index`，以及一个占用四字节的`attribute_length`。**

但虚拟机根据读取到`attribute_name_index`进行的后续解析步骤是不同的，比如对于`Exceptions`，后续的信息为`number_of_exceptions`与`exception_index_table`，而`LineNumberTable`后续的信息为`line_number_table_length`及`line_number_table`，它们的格式和占用空间的大小都是不同的，只有依赖事先定义好的规范，才能将对应属性的正确信息解析出来。

> tips: 这个表格比较复杂，建议有相关需求和兴趣的同学们直接查看官方的Java虚拟机规范文档：https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-4.html#jvms-4.7

# 4.总结

Class文件中记录了很多关键的信息，了解Class文件的结构能够帮助我们更深入地理解Java运行原理。

我们在最后对Class文件中的结构做一个简单的分类，大家一条一条看下去，也跟着思考一下，如果不保存这一信息会怎么样，会不会影响代码的运行？这个信息具体保存在Class文件的哪一部分？

Class文件结构分类：

1. 结构信息

2. - Class文件格式版本号
   - 各部分的数量及所占空间大小

3. 元数据（对应Java源代码中“声明”和“常量”信息）

4. - 类 / 继承的超类 / 实现接口的声明信息
   - 域 / 方法 的声明信息
   - 常量池
   - 运行期注解

5. 方法信息（对应Java源代码中“语句”与“表达式”信息）

6. - 字节码
   - 异常处理器表
   - 操作数栈 与 局部变量区 的大小
   - 符号信息（如LineNumberTable、LocalVariableTable）

我是敖丙，你知道的越多，你不知道的越多，下期见！