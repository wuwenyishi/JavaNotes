# 带你手写字性能提升2倍以上的符串切割工具类            



#### 目录

- 工作中常用的split()切割字符串效率高么？
- JDK提供字符串切割工具类StringTokenizer
- 手把手带你实现一个更高效的字符串切割工具类
- 总结

今天给大家介绍一个小知识点，但是会非常的实用，就是平时我们写Java代码的时候，如果要对字符串进行切割，我们可以巧妙的运用一些技巧**把性能提升5~10倍**。废话不多说，直接给大家上干货！

#### 工作中常用的split()切割字符串效率高吗？

首先，我们用下面的一段代码，去拼接出来一个**用逗号分隔的超长字符串**，把从0开始一直到9999的每个数字都用逗号分隔，拼接成一个超长的字符串，以便于我们可以进行实验，代码如下所示：

```java
public class StringSplitTest {

    public static void main(String[] args) {
        String string = null;
        StringBuffer stringBuffer = new StringBuffer();

        int max = 10000;
        for(int i = 0; i < max; i++) {
            stringBuffer.append(i);
            if(i < max - 1) {
                stringBuffer.append(",");
            }
        }
        string = stringBuffer.toString();
    }

}
复制代码
```

接着我们可以用下面的代码来测试一下，如果用最基础的split方法来对超长字符串做切割，循环切割**1w次**，要耗费多长时间，看如下代码测试：

```java
public class StringSplitTest {

    public static void main(String[] args) {
        String string = null;
        StringBuffer stringBuffer = new StringBuffer();

        int max = 10000;
        for(int i = 0; i < max; i++) {
            stringBuffer.append(i);
            if(i < max - 1) {
                stringBuffer.append(",");
            }
        }
        string = stringBuffer.toString();

        long start = System.currentTimeMillis();
        for(int i = 0; i < 10000; i++) {
            string.split(",");
        }
        long end = System.currentTimeMillis();
        System.out.println(end - start);
    }

}
复制代码
```

经过上面代码的测试，最终发现用split方法对字符串按照逗号进行切割，**切割1w次是耗时2000多毫秒，这个不太固定，大概是2300毫秒左右**。

#### JDK提供字符串切割工具类StringTokenizer

接着给大家介绍另外一个性能更加好的专门用于字符串切割的工具类，就是**StringTokenizer**，这个工具是JDK提供的，也是专门用来进行字符串切割的，他的性能会更好一些，我们可以看下面的代码，用他来进行1w次字符串切割，看看具体的性能测试结果如何：

```java
import java.util.StringTokenizer;

public class StringSplitTest {

    public static void main(String[] args) {
        String string = null;
        StringBuffer stringBuffer = new StringBuffer();

        int max = 10000;
        for(int i = 0; i < max; i++) {
            stringBuffer.append(i);
            if(i < max - 1) {
                stringBuffer.append(",");
            }
        }
        string = stringBuffer.toString();

        long start = System.currentTimeMillis();
        for(int i = 0; i < 10000; i++) {
            string.split(",");
        }
        long end = System.currentTimeMillis();
        System.out.println(end - start);

        start = System.currentTimeMillis();
        StringTokenizer stringTokenizer =
                new StringTokenizer(string, ",");
        for(int i = 0; i < 10000; i++) {
            while(stringTokenizer.hasMoreTokens()) {
                stringTokenizer.nextToken();
            }
            stringTokenizer = new StringTokenizer(string, ",");
        }
        end = System.currentTimeMillis();
        System.out.println(end - start);
    }

}
复制代码
```

大家看上面的代码，用StringTokenizer可以通过hasMoreTokens()方法判断是否有切割出的下一个元素，如果有就用nextToken()拿到这个切割出来的元素，一次全部切割完毕后，就重新创建一个新的StringTokenizer对象。

这样连续切割1w次，经过测试之后，会发现用StringTokenizer切割字符串1w次的耗时大概是**1900毫秒**左右。 大家感觉如何？是不是看到差距了？换一下切割字符串的方式，就可以让**耗时减少400~500ms**，性能目前已经可以提升20%了。

#### 手把手带你实现一个更高效的字符串切割工具类

接着我们来自己封装一个切割字符串的函数，用这个函数再来做一次字符串切割看看，大家先看字符串切割函数的代码：

```java
private static void split(String string) {
  String remainString = string;
  int startIndex = 0;
  int endIndex = 0;
  while(true) {
    endIndex = remainString.indexOf(",", startIndex);
    if(endIndex <= 0) {
      break;
    }
    remainString.substring(startIndex, endIndex);
    startIndex = endIndex + 1;
  }
}
复制代码
```

上面那段代码是我们自定义的字符串切割函数，大概意思是说，每一次切割都走一个while循环，startIndex初始值是0，然后每一次循环都找到从startIndex开始的下一个逗号的index，就是endIndex，基于startIndex和endIndex截取一个字符串出来，然后startIndex可以推进到本次endIndex + 1即可，下一次循环就会截取下一个逗号之前的子字符串了。 下面我们用用上述自定义的切割函数再次测试一下，如下代码：

```java
import java.util.StringTokenizer;

public class StringSplitTest {

    public static void main(String[] args) {
        String string = null;
        StringBuffer stringBuffer = new StringBuffer();

        int max = 10000;
        for(int i = 0; i < max; i++) {
            stringBuffer.append(i);
            if(i < max - 1) {
                stringBuffer.append(",");
            }
        }
        string = stringBuffer.toString();

        long start = System.currentTimeMillis();
        for(int i = 0; i < 10000; i++) {
            string.split(",");
        }
        long end = System.currentTimeMillis();
        System.out.println(end - start);

        start = System.currentTimeMillis();
        StringTokenizer stringTokenizer =
                new StringTokenizer(string, ",");
        for(int i = 0; i < 10000; i++) {
            while(stringTokenizer.hasMoreTokens()) {
                stringTokenizer.nextToken();
            }
            stringTokenizer = new StringTokenizer(string, ",");
        }
        end = System.currentTimeMillis();
        System.out.println(end - start);

        start = System.currentTimeMillis();
        for(int i = 0; i < 10000; i++) {
            split(string);
        }
        end = System.currentTimeMillis();
        System.out.println(end - start);
    }

    private static void split(String string) {
        String remainString = string;
        int startIndex = 0;
        int endIndex = 0;
        while(true) {
            endIndex = remainString.indexOf(",", startIndex);
            if(endIndex <= 0) {
                break;
            }
            remainString.substring(startIndex, endIndex);
            startIndex = endIndex + 1;
        }
    }

}
复制代码
```

#### 总结

经过上述代码测试之后，我们自己写的字符串切割函数的耗时大概是在**1000ms左右**，相比较之下，比**String.split**方法的性能提升了2倍多，比**StringTokenizer**的性能也提升了2倍，如果要是字符串更大呢？其实字符串越大，性能差距就会越多，可能会呈更大的倍数提升我们的性能！


作者：石杉的架构笔记
链接：https://juejin.cn/post/7081426912681132039
来源：稀土掘金
著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。