# 敖丙字节一面：能聊聊字节码么？



# 1.前言

上一篇《[你能和我聊聊Class文件么](http://mp.weixin.qq.com/s?__biz=MzAwNDA2OTM1Ng==&mid=2453157347&idx=1&sn=e8873bac7b92163ce2d54df41d06f4dc&chksm=8cfd1760bb8a9e76ce2511032ed652708b57fcd0daf00916cda9f3ec8019d7538031d35fb4a7&scene=21#wechat_redirect)》中，我们对Class文件的各个部分做了简单的介绍，当时留了一个很重要的部分没讲，不是敖丙不想讲啊，而是这一部分实在太重要了，不独立成篇好好zhejinrong 讲讲都对不起詹姆斯·高斯林。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155220.jpeg)

这最重要的部分当然就是**字节码**啦。

先来个定义：**Java字节码是一组可以由Java虚拟机(JVM)执行的高度优化的指令，它被记录在Class文件中，在虚拟机加载Class文件时执行。**

> 说大白话就是，字节码是Java虚拟机能够看明白的可执行指令。

前面的文章中已经强调了很多次了，**Class文件不等于字节码**，为什么我要一直强调这个事情呢？

因为在绝大部分的中文资料和博客中，这两个东西都被严重的弄混了...

导致现在一说字节码大家就会以为和Class文件是同一个东西，甚至有的文章直接把Class文件称为“字节码”文件。

这样的理解显然是有偏差的。

举个例子，比如我们所熟知的`.exe`可执行文件，`.exe`文件中包含机器指令，但除了机器指令之外，`.exe`文件还包含其他与准备执行这些指令相关的信息。

因此我们不能说“机器指令”就是`.exe`文件，也不能把`.exe`文件称为“机器指令”文件，它们只是一种包含关系，仅此而已。

同样的，Class文件并不等于字节码，只能说Class文件包含字节码。

上次的文章中我们提到，**字节码（或者称为字节码指令）被存储在Class文件中的方法表中，它以Code属性的形式存在**。

因此，可以**通俗地说，字节码就是Class文件方法表（methods）中的Code属性。**

今天我们来好好聊聊字节码~

但是在讲字节码知识之前我们需要对Java虚拟机（Java Virtual Machine，简称JVM）的内部结构有一个简单的理解，毕竟字节码说到底**指示虚拟机各个部分需要执行什么操作的命令**，先简单了解JVM，知己知彼方能百战百胜。

# 2、JVM的内部结构

我们借这么一张图来稍微聊聊JVM执行Class文件的流程。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155228.png)

这是学习JVM过程中躲不开的一张图，当然我们今天不讲那么深。

**字节码是对方法执行过程的抽象**，于是我们今天只把跟方法执行过程**最直接相关**的几个部分拎出来讲讲。

> 其实虚拟机执行代码时，虚拟机中的每一部分都需要参与其中，但本篇我们更关注的是跟"执行过程"相关的几个部分，也就是**跟代码顺序执行这一动态过程**相关的几个部分。有点云里雾里了吗，不要急，往下看。

以Hello.class作为今天的主角。

当Hello.class被加载时，首先经历的是**Class文件中的信息**被加载到JVM**方法区**中的过程。

方法区是什么？

**方法区是存储方法运行相关信息的一个区域**。

如果把Class文件中的信息理解为**一颗颗的子弹**，那么方法区就可以看做是成JVM的"弹药库"，而将**Class文件中的信息加载到方法区这一过程相当于“子弹上膛”**。

只有当子弹上膛后，JVM才具备了“开火”的能力，这很合理吧。

例如，原本记录在Class文件中的**常量池**，此时被加载到方法区中，成为**运行时常量池**。同时，**字节码指令**也被装配到方法区中，为方法的运行提供支持。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155238.gif)类加载动图

当类Hello.class被加载到方法区后，JVM会为Hello这个类在**堆**上新建一个**类对象**。

第二个知识点来咯：堆是 **放置对象实例的地方，所有的对象实例以及数组都应当在运行时分配在堆上。**

一般在执行新建对象相关操作时（例如 new HashMap），才会在堆上生成对象。

但是你看，我们明明还没开始执行代码呢，这才刚处于类的加载阶段，堆上就开始进行对象分配了，**难道有什么特殊的对象实例在类加载的时候就被创建了吗？**

没错，这个实例的确特殊，**它就是我们在反射时常常会用到的 java.lang.Class对象！！！**

如果你忘了什么是反射的话，我来提醒你一下：

```
Hello obj = new Hello();
Class<?> clz = obj.getClass();
```

在Hello这个类的Class文件被加载到方法区的之后，JVM就在堆区为这个新加载的Hello类建立了一个java.lang.Class实例。

说到这里，你对”Java是一门面向对象的语言“这句话有没有更深入的理解——**在Java中，即使连类也是作为对象而存在的**。

不仅如此，由于JDK 7之后，**类的静态变量存放在该类对应的java.lang.Class对象中**。因此当 java.lang.Class在堆上分配好之后，静态变量也将被分配空间，并获得最初的零值。

> 注意，**这里的零值指的不是静态变量初始化哦**，仅仅只是在类对象空间分配后，JVM为所有的静态变量赋了一个**用于占位的零值**，零值很好理解嘛，也就是数值对象被设为0，引用类型被设为null。

到这里为止，类的信息已经完全准备好了，接下来要开始的，就是执行<cliinit>方法。我们在《Java代码编译流程是怎样的》一文中讨论过，<clinit>方法是类的构造方法，它的作用是初试化类中所有的静态变量并执行用`static {}`包裹的代码块，而且该方法的收集是有顺序的：

1. 父类静态变量初始化 及 父类静态代码块；
2. 子类静态变量初始化 及 子类静态代码块。

**<clinit>方法相当于是把静态的代码打包在一起执行**，而且<clinit>函数是在**编译时**就已经将这些与类相关的初始化代码按顺序收集在一起了，因此在Class文件中可以看到<clinit>函数：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155300.png)

> 当然，如果类中既没有静态变量，也没有静态代码块，则不会有<clinit>函数。

总之，如果<clinit>函数存在，那么在类被加载到JVM之后，<clinit>函数开始执行，初始化静态变量。

接下来我们今天最重要的部分要登场了！！！

**就决定是你了，虚拟机栈！！**

第三个知识点：**虚拟机栈是线程中的方法的内存模型。**

上面这句话听着很抽象是吧，没事，我来好好解释一下。

首先要明白的是，**虚拟机栈，顾名思义是用栈结构实现的一种的线性表**，其限制是仅允许在表的**同一端进行插入和删除运算**，这一端被称为栈顶，相对地，把另一端称为栈底。

栈的特性是每次操作都是从栈顶进或者从栈顶出，且满足先进后出的顺序，而虚拟机栈也继承了这一优良传统。

**虚拟机栈是与方法执行最直接相关的一个区域**，用于记录Java方法调用的“活动记录”（activation record）。

虚拟机栈以**栈帧**（frame）为单位线程的运行状态，每调用一个方法就会分配一个新的栈帧压入Java栈上，每从一个方法返回则弹出并撤销相应的栈帧。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155310.png)

例如，这么一段代码：

```
public class Hello {
    public static int a = 0;
    public static void main(String[] args) {
        add(1,2);
    }

    public static int add(int x,int y) {
        int z = x+y;
        System.out.println(z);
        return z;
    }
}
```

它的调用链如下：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155318.gif)

调用链

现在你明白了吧，**代码中层层调用的概念在JVM里是使用栈数据结构来实现的**，调用方法时生成栈帧并入栈，方法执行完出栈，直到所有方法都出栈了，就意味着整个调用链结束。

还记得二叉树的前序遍历怎么写的吗：

```
public void preOrderTraverse(TreeNode root) {
  if (root != null) {
    System.out.print(root.val + "->");
    preOrderTraverse(root.left);
    preOrderTraverse(root.right);
  }
}
```

这种**递归形式本质上就是利用虚拟机栈**对同一个方法的递归入栈实现的，如果我们写成非递归形式的前序遍历，应该是这样子的：

```
public void preOrderTraverse(TreeNode root) {
  // 自己声明一个栈
  Stack<TreeNode> stack = new Stack<>();
  TreeNode node = root;
  while (node != null || !stack.empty()) {
    if (node != null) {
      System.out.print(node.val + "->");
      stack.push(node);
      node = node.left;
    } else {
      TreeNode tem = stack.pop();
      node = tem.right;
    }
  }
}
```

二叉树遍历的**非递归形式就是由我们自己把栈写好**，并实现出栈入栈的功能，跟递归方式调用的本质是相似的，只不过**递归操作中我们依赖虚拟机栈来执行入栈出栈**。

总之，靠**栈**可以很好地表达方法间的这种层层调用的层级关系。

当然，栈空间是有限的，如果只有入栈没有出栈，最后必然会出现空间不足，同时也就会报出经典的`StackOverflowError`（栈溢出错误），最常见的导致栈溢出的情况就是递归函数里忘了写终止条件。

其次，多个线程的方法执行应当为独立且互不干扰的，因此**每一个线程都拥有自己独立的一个虚拟机栈**。

这也导致了各个线程之间方法的执行速度并不能保持一致，有时A线程先执行完，有时B线程先执行完，究其原因就是因为虚拟机栈是线程私有，各自独立执行。

谈完了**虚拟机栈**的整体情况，我们再来看看虚拟机栈中的**栈帧**。

**栈帧是虚拟机栈中的基础元素，它随着方法的调用而创建，记录了被调用方法的运行需要的重要信息，并随着方法的结束而消亡。**

那么你就要问了，**栈帧里到底包裹了些什么东西呀？**

好的同学，等我把这个问题回答完，今天的知识你至少就懂了一半。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155351.png)

# 3、栈帧的组成

栈帧主要由以下几个部分组成：

1. 局部变量表
2. 操作数栈
3. 动态连接
4. 方法出口
5. 其他信息

## 3.1 局部变量表

局部变量表（Local Variable Table）是一个用于存储**方法参数**和**方法内部定义的局部变量**的空间。

**一个重要的特性是，在Java代码被编译为Class文件时，就已经确定了该方法所需要分配的局部变量表的最大容量。**

也就是说，早在代码编译阶段，就已经把局部变量表需要分配的大小计算好了，并记录在Class文件中，例如：

```
public class Hello {
    public static void main(String[] args) {
        for (int i=0;i<3;i++){
            System.out.printf(i+"");
        }
    }
}
```

这个类的main方法，通过`javap`之后可以得到其中的局部变量表：

```
LocalVariableTable:
        Start  Length  Slot  Name   Signature
            2      41     1     i   I
            0      44     0  args   [Ljava/lang/String;
```

这个意思就是告诉你，这个方法会产生两个局部变量，`Slot`代表他们在局部变量表中的下标。

难道方法里定义了多少个局部变量，局部变量表就会分配多少个Slot坑位吗？

不不不，编译器精明地很，它会采取一种称为`Slot复用`的方法来节省空间，举个例子，我们为前面的方法再增加一个for循环：

```
public class Hello {
    public static void main(String[] args) {
        for (int i=0;i<3;i++){
            System.out.printf(i+"");
        }
        for (int j=0;j<3;j++){
            System.out.printf(j+"");
        }
    }
}
```

然后会得到如下局部变量表：

```
LocalVariableTable:
        Start  Length  Slot  Name   Signature
            2      41     1     i   I
           45      41     1     j   I
            0      87     0  args   [Ljava/lang/String;
```

虽然还是三个变量，但是`i`和`j`的`Slot`是同一个，也就是说，**他们共用了同一个下标，在局部变量表中占的是同一个坑位**。

至于原因呢，相信聪明的你已经看出来了，跟局部变量的作用域有关系。

变量`i`作用域是第一个for循环的内部，而当变量`j`创建时，`i`的生命周期就已经结束了。因此`j`可以复用`i`的`Slot`将其覆盖掉，以此来节省空间。

所以，虽然看起来创建了三个局部变量，但其实只需要分配两个变量的空间。

## 3.2 操作数栈

栈帧中的第二个重要部分是操作数栈。

等等，这怎么又来了个栈，搁这套娃呢？？？

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155357.png)

没办法呀，栈这玩意实在太好用了，首先栈的**基本操作非常简单**，只有入栈和出栈两种，这个优势可以保证每一条JVM的指令都代码紧凑且体积小；其次**栈用来求值**也是非常经典的用法，简单又方便喔。

> 也有一种基于寄存器的体系结构，将局部变量表与操作数栈的功能组合在一起，关于这两种体系优劣势的详细讨论可以移步至R大的博客：https://www.iteye.com/blog/rednaxelafx-492667
>
> 至于用栈来求值这种用法，大家在《数据结构》课上学栈这一结构的时候应该都接触过了，这里不多展开。如果没有印象了，建议看看Leetcode上的这一题：https://leetcode-cn.com/problems/evaluate-reverse-polish-notation/

总之，情况就是这么个情况，**虚拟机栈的每一个栈帧里都包含着一个操作数栈**，作用是**保存求值的中间结果和调用别的方法的参数**等。

## 3.3 动态连接

**动态连接**这个名词在全网的JVM中文资料中解释得非常混乱，在你基础没有打牢之前不建议你深入去细究，脑子会乱掉的。

我这里会给大家一个非常通俗易懂的解释，了解即可。

首先，栈帧中的这个动态连接，英文是**Dynamic Linking**，Linking在这里是作为名词存在的，跟前面的表、栈是同一个层次的东西。

这个连接说白了就是**栈帧的当前方法指向运行时常量池的一个引用**。

为什么需要有这个引用呢？

前面说了，Class文件中关键信息都保存在方法区中，所以**方法执行的时候生成的栈帧得知道自己执行的是哪个方法**，靠的就是这个动态连接直接引用了方法区中该方法的实际内存位置，然后再**根据这个引用，读取其中的字节码指令**。

至于"动态"二字，牵扯到的就是Java的**继承和多态**的机制，有的类继承了其他的类并重写了父类中的方法，因此在运行时，需要"动态地"识别应该要连接的实际的类、以及需要执行的具体的方法是哪一个。

## 3.4 方法出口

当一个方法开始执行，只有两种方式退出这个方法，**第一种方式是正常返回**，即遇到了`return`语句，**另一种方式则是在执行中遇到了异常**，需要向上抛出。

无论是那种形式的返回，在此方法退出之后，**虚拟机栈都应该退回到该方法被上层方法调用时的位置**。

**栈帧中的方法出口记录的就是被调用的方法退出后应该回到上层方法的什么位置。**

------

好了，到这里为止，栈帧中的内容就介绍结束了，接下来我们用一个简单的例子来了解字节码指令，以及执行执行时JVM各区域的运行过程。

# 4、实例：++i与i++的字节码实例

```
public class Hello {
    public static int a = 0;
    public static void main(String[] args) {
        int b = 0;
        b = b++;
        System.out.println(b);
        b = ++b;
        System.out.println(b);
        a = a++;
        System.out.println(a);
       a = ++a;
        System.out.println(a);
    }
}
```

这段程序的输出会是是这样的：

```
0
1
0
1
```

这是初学Java时一道经典的误导题，大家可能已经知其然，一眼就能看出正确的结果，可对于最底层的原理却未必知其所以然。

`b=b++`执行完后变量`b`并没有发生变化，只有在`b=++b`时变量`b`才自增成功。

这里其实涉及到自增操作在字节码层面的实现问题。

我们先来看看这一段代码对应的字节码是怎样的，使用`jclasslib`来查看`Hello`类的`main`方法中的`Code`属性：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155409.png)

将Code中的信息粘贴出来：

```
 0 iconst_0
 1 istore_1
 2 iload_1
 3 iinc 1 by 1
 6 istore_1
 7 getstatic #2 <java/lang/System.out : Ljava/io/PrintStream;>
10 iload_1
11 invokevirtual #3 <java/io/PrintStream.println : (I)V>
14 iinc 1 by 1
17 iload_1
18 istore_1
19 getstatic #2 <java/lang/System.out : Ljava/io/PrintStream;>
22 iload_1
23 invokevirtual #3 <java/io/PrintStream.println : (I)V>
26 getstatic #4 <com/cc/demo/Hello.a : I>
29 dup
30 iconst_1
31 iadd
32 putstatic #4 <com/cc/demo/Hello.a : I>
35 putstatic #4 <com/cc/demo/Hello.a : I>
38 getstatic #2 <java/lang/System.out : Ljava/io/PrintStream;>
41 getstatic #4 <com/cc/demo/Hello.a : I>
44 invokevirtual #3 <java/io/PrintStream.println : (I)V>
47 getstatic #4 <com/cc/demo/Hello.a : I>
50 iconst_1
51 iadd
52 dup
53 putstatic #4 <com/cc/demo/Hello.a : I>
56 putstatic #4 <com/cc/demo/Hello.a : I>
59 getstatic #2 <java/lang/System.out : Ljava/io/PrintStream;>
62 getstatic #4 <com/cc/demo/Hello.a : I>
65 invokevirtual #3 <java/io/PrintStream.println : (I)V>
68 return
```

Emmm....看起来有点密密麻麻，不知道该从哪看起。

其实阅读字节码指令是有技巧的，字节码和源码的对应关系已经记录在了字节码中，也就是`Code`属性中的`LineNumberTable`，这里记录的是**源码的行号和字节码行号的对应关系**。

如图，右侧的**起始PC指的是字节码的起始行号**，**行号则是字节码对应的源码行号**。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155412.png)

将这个例子中的源码和字节码对应起来的效果如图所示：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155421.png)

这么一对应，是不是就清晰很多了？

掌握了这个技巧之后我们就可以开始分析整体的流程和细节了。

## 4.1 静态变量赋值

首先来捋一捋，当Hello类加载到JVM之后发生了什么，按我们前面说的，加载完成之后，虚拟机栈需要进行方法入栈，而众所周知，main方法是执行的入口，所以main方法最先入栈。

但是，是这样的吗？

别忘记了这一行代码：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155429.png)

静态变量的赋值需要在main方法之前执行，前面已经提到了，静态变量的赋值操作被封装在<clinit>方法中。

因此，**<clinit>方法需要先于main方法入栈执行**，在本例中，<clinit>方法长这样：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155433.png)

当然，<clinit>方法的LineNumberTable也记录了字节码跟源码的对应关系，只不过在这里对应源码只有一行：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155438.png)

因此`public static int a = 0;`这一行源代码就对应了三行的字节码：

```
0 iconst_0
1 putstatic #4 <com/cc/demo/Hello.a : I>
4 return
```

简直没有比这更适合作为字节码教学入门素材的了！！

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155443.png)

接下来就可以开始愉快地手撕字节码了。

第一句`iconst_0`，在官方的JVM规范中是这么解释的：“Push the int constant <*i*>  onto the operand stack”，也就是说**iconst操作是把一个int类型的常量数据压入到操作数栈的栈顶**。

这个指令开头的字母表示的是类型，在本例中`i`代表int。我们可以举一反三，当然还会有`lconst`代表把long类型的常量入栈到栈顶，有`fconst`指令表示把float类型的常量推到栈顶等等等等。

这个指令结尾的数字就是需要入栈的值了~

恭喜你，看完上面这段话，你至少已经学会了n种字节码指令了。

不就是排列组合嘛，so easy！

再来看第二句，`putstatic #4`，光看字面意思就能很容易的猜出它的作用，这个指令的含义是**：当前操作数栈顶出栈，并给静态字段赋值**。

把刚才放到操作数栈顶的`0`拿出来，赋值给常量池中`#4`位置字面量表示的静态变量，这里可以看到`#4`位置的字面量就是`<com/cc/demo/Hello.a : I>`。

所以，这第二行字节码，本质上是一个赋值操作，将`0`这个值赋给了静态变量`a`。

> 静态变量存储在堆中该类对应的Class对象实例中，也就是我们在反射机制中用对应类名拿到的那个Class对象实例。

最后一行是一个`return`，这个没啥好说的。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155449.gif)

好了，这就是本例中的<clinit>方法中的全部了，并不难吧。

**当<clinit>方法执行完出栈后，main方法入栈，开始执行main方法Code属性中的字节码指令。**

为了方便讲解，接下来我会逐行将源码与其对应的字节码贴在一起。

## 4.2 局部变量赋值

首先是源码中的第六行 ，也就是main函数的第一句：

```
//Source code
int b = 0;

//Byte code
 0 iconst_0
 1 istore_1
```

这一句源码对应了两行字节码。

其中，`iconst_0`这个在前面已经讲过了，将int类型的常量从栈顶压入，由于此时操作数栈为空，所以`0`被压入后理所当然地既是栈顶，也是栈底。

然后是`istore_1`命令，这个跟`iconst_0`的结构很像，**以一个类型缩写开头，以一个数字结尾**，那么我们只要弄清楚`store`的含义就行了，`store`表示**将栈顶的对应类型元素出栈，并保存到局部变量表指定位置中**。

由于此时的栈顶元素就是刚才压入的int类型的`0`，所以我们要存储到局部变量表中的就是这个`0`。

那么问题来了，这个值需要放到局部变量表中的哪个位置呢？

在`iconst_0`命令中，末尾的数字代表需要入栈的常量，但在`istore_1`命令中，操作数是从操作数栈中取出的，是不用声明的，那`istore_1`命令末尾这个数字的用途是什么呢？

前面说了，`store`表示将栈顶的对应类型元素保存到局部变量表**指定位置**中。

因此`iconst_0`指令末尾这个数字代表就是**指定位置**啦，也就是**局部变量表的下标**。

从`LocalVariableTable`中可以看出，下标为1的位置中存储的就是局部变量b。

> 下标0位置存储的是方法的入参。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155501.png)

总之，`istore_1`这个命令就意味着栈顶的int元素出栈，并保存到局部变量表下标为1的位置中。

> 同样的，`stroe`这个命令也可以与各种类型缩写的开头组合成不同的命令，像什么`lstroe`、`fstore`等等。

ok，这又是一个经典的声明和赋值操作。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155505.gif)

## 4.3 局部变量自增

### 4.3.1 i++过程

我们继续往下看，源码第七行和它对应的字节码：

```
//Source code
b = b++;

//Byte code
 2 iload_1
 3 iinc 1 by 1
 6 istore_1
```

首先是`iload_1`命令，这个命令是与`istore_1`命令对应的反向命令。

`store`不是从操作数栈栈顶取数存到局部变量表中嘛，那么`load`要做的事情恰恰相反，它做的是**从局部变量表指定位置中取数值，并压入到操作数栈的栈顶**。

那么`iload_1`详细来说就是：**从局部变量表的位置1中取出int类型的值，并压入操作数栈**。

但是，这里的取值操作其实是一个“拷贝”操作：**从局部变量表中取出一个数，其实是将该值复制一份，然后压入操作数栈，而局部变量表中的数值还保存着，没有消失**。

然后是一个`iinc 1 by 1`指令，这是一个**双参数指令**，主要的功能是**将局部变量表中的值自增一个常量值**。

`iinc`指令的**第一个参数值的含义是局部变量表下标**，**第二个参数值需要增加的常量值**。

因此**`iinc 1 by 1`就表示局部变量表中下标为1位置的值增加1。**

再来看第三条指令`istore_1`，这个很熟悉了，操作数栈栈顶元素出栈，存到局部变量表中下标为1的位置。

等等，是不是有什么奇怪的事情发生了。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155508.png)

**`iinc 1 by 1`就表示局部变量表中下标为1位置的值由0变成了1，但是`istore_1`把一开始从局部变量表下标1复制到操作数栈的0值又赋值到了下标位置1。**

因此无论中间局部变量表中的对应元素做了什么操作，到了这一步都直接白费功夫，相当于是脱裤子放屁了。

来个动图，看得更清晰：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155511.gif)局部变量b++流程

因此`b = b++`从字节码上来看，自增后又被初始值覆盖了，最终自增失败。

继续看下一句：

```
//Source code
System.out.println(b);

//Byte code
 7 getstatic #2 <java/lang/System.out : Ljava/io/PrintStream;>
10 iload_1
11 invokevirtual #3 <java/io/PrintStream.println : (I)V>
```

这一句是与控制台打印有关的字节码，与今天的主题联系不大，稍微过一下即可。

`getstatic #2`是**获取常量池中索引为`#2`的字面量对应的静态元素**。

`iload_1` 从局部变量表中索引为1的位置取数值，并压入到操作数栈的栈顶，这里取的就是变量`b`的值啦。

然后最后一句是`invokevirtual #3`，**invoke这个单词我们在代理模式中也经常见到，是调用的意思**，因此`invokevirtual #3`代表的就是 **调用常量池索引为3的字面量对应的方法**，这里的对应方法就是`java/io/PrintStream.println`，

最终，将变量`b`的值打印出来。

### 4.3.2 ++i过程

再来看看`++b`操作：

```
//Source code
b = ++b;

//Byte code
14 iinc 1 by 1
17 iload_1
18 istore_1
```

这里的三行字节码与前面讲解的`b=b++`中的字节码完全一样，只是**顺序发生了变化**：

先在局部变量表中自增（`iinc 1 by 1`），然后再入栈到操作数栈中（`iload_1`），最后出栈保存到局部变量表中（`istore_1`）。

先自增就保证了自增操作是有效的，不管后面怎么折腾，**参与的都是已经自增后的值**，来个动图：

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155517.gif)

## 4.4 静态变量自增

最后我们看看静态变量`a`的自增操作：

```
//Source code
a = a++;

//Byte code
26 getstatic #4 <com/cc/demo/Hello.a : I>
29 dup
30 iconst_1
31 iadd
32 putstatic #4 <com/cc/demo/Hello.a : I>
35 putstatic #4 <com/cc/demo/Hello.a : I>
```

`getstatic #4`就是获取常量池中索引为`#4`的字面量对应的静态字段。前面已经讲过了，这一步是到堆中去拿的，拿到静态变量的值以后，会放到当前栈帧的操作数栈。

然后执行`dup`操作，**dup是duplicate的缩写**，意思是复制。

`dup`指令的意义就是**复制顶部操作数堆栈值并压入栈中**，也就是说此时的**栈顶有两个一模一样的元素**。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155513.png)

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155616.png)

这是个什么操作啊，两份一样的值能干什么，别急，我们继续往下看。

随后是一个`iconst_1`，将int类型的数值`1`压入栈顶。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155613.png)

然后是一个`iadd`指令，这个指令是将**操作数栈栈顶的两个int类型元素弹出并进行加法运算**，最后将求得的**结果压入栈中**。

像这种两个值进行数值运算的操作，其实是操作数栈中除了简单的入栈出栈外最常见的操作了。

类似的还有`isub`——栈顶两个值相减后结果入栈，`imul`——栈顶两个值相乘后结果入栈等等。

总之，此时的栈顶最上面的两个元素是刚刚压入栈的常量`1`以及静态变量a的值`0`（这是刚才dup之后压入栈的那个），这两数一加，结果入栈，那还是个`1`。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155553.png)

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155607.png)

接下来的指令是一个` putstatic #4`，取栈顶元素出栈并赋值给静态变量，这里当然就是静态变量`a`啦。

因此静态变量a的值就自增完成，变成了`1`。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155549.gif)

可是！！！

事情到这里还没结束，因为字节码中清清楚楚地记录着随后又进行了一次` putstatic #4`操作。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155546.gif)

此时的栈顶元素就是最开始从堆中取过来的变量`a`的初始值`0`，现在把这个值出栈，又赋值给了`a`，这不是中间的操作都白费了吗？

静态变量`a`的值又变成`0`了。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155543.png)

等等，这一波脱裤子放屁的操作怎么似曾相识？

前面局部变量`b = b++`好像也经历过这么一个过程，**先复制一份自己**到操作数栈中，然后**局部变量表**里的值**一顿操作**，最后操作数栈中的**原始值又跑回去把自己给覆盖了**。

静态变量不远万里从堆中赶到操作数栈，**先复制一份自己**造了个分身到操作数栈栈顶，随后对这个**栈顶的分身一顿操作**，最后留在操作数栈中的**原始值又跑回去把自己给覆盖了**。

难道说，这波复制操作是因为**静态变量需要分配一个位置充当局部变量表的作用，另一个位置需要充当操作数栈位置的作用？**

为了验证这个猜测是否正确，我们最后来看看`a = ++a`：

```
//Source code
a = ++a;

//Byte code
47 getstatic #4 <com/cc/demo/Hello.a : I>
50 iconst_1
51 iadd
52 dup
53 putstatic #4 <com/cc/demo/Hello.a : I>
56 putstatic #4 <com/cc/demo/Hello.a : I>
```

相信大家阅读这一段字节码已经没有问题了，我只讲讲中间几句最重要的：

静态变量`a`从堆中被复制到操作数栈之后，紧跟的是一个`iconst_1`，将int类型的数值`1`压入栈顶。

然后是一个`iadd`指令，将**操作数栈栈顶的两个int类型元素弹出并进行加法运算**，也就是刚刚压入栈的常量`1`以及静态变量a的值`0`进行求和操作。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155536.png)

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155533.png)

这两数一加，结果入栈，那就是个`1`。

![图片](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/03/31/155530.png)

接下来有意思了，进行了一次`dup`操作，那操作数栈中的栈顶此时就有两个`1`了。

**这跟执行`++b`时，局部变量先在局部变量表中自增，再复制一份到操作数栈的操作是不是很像？**

然后是两个` putstatic #4`，取栈顶元素出栈并赋值给静态变量，现在栈顶两个都是`1`，**即使赋值两次，最终静态变量a的值还得是`1`啦**。

懂了吗宝，一切的源头就是因为**静态变量被加载到栈帧后不能加入局部变量表**，因此它将自己的一个分身压到栈顶，现在操作数栈中有两个一模一样的值，**一个充当局部变量表的作用，另一个充当正常操作数栈位置的作用**。

# 5.小结

俗话说，授人以鱼不如授人以渔。本文通过对虚拟机结构的简单介绍，慢慢引申到字节码的执行的过程。

最后用两个例子一步一步手撕字节码，跟着这个思路思考，相信大家以后遇到字节码的问题也能稍微有点头绪了吧。

这里面知识点很多，但只要理解了原理，一起都变得有迹可循，即使遇到复杂的字节码，在需要用到时再去查询对应字节码的含义就行啦~

我是敖丙，**你知道的越多，你不知道的越多**，感谢各位臭宝的：**点赞**、**收藏**和**评论**，我们下期见！