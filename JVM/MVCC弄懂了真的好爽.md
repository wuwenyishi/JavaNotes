<title>MVCC弄懂了真的好爽</title>



## 1. 隔离级别

### 1.1 理论

MySQL 中事务的隔离级别一共分为四种，分别如下：

- 序列化（SERIALIZABLE）
- 可重复读（REPEATABLE READ）
- 提交读（READ COMMITTED）
- 未提交读（READ UNCOMMITTED）

四种不同的隔离级别含义分别如下：

1. SERIALIZABLE

> 如果隔离级别为序列化，则用户之间通过一个接一个顺序地执行当前的事务，这种隔离级别提供了事务之间最大限度的隔离。

1. REPEATABLE READ

> 在可重复读在这一隔离级别上，事务不会被看成是一个序列。不过，当前正在执行事务的变化仍然不能被外部看到，也就是说，如果用户在另外一个事务中执行同条 SELECT 语句数次，结果总是相同的。（因为正在执行的事务所产生的数据变化不能被外部看到）。

1. READ COMMITTED

> READ COMMITTED 隔离级别的安全性比 REPEATABLE READ 隔离级别的安全性要差。处于 READ COMMITTED 级别的事务可以看到其他事务对数据的修改。也就是说，在事务处理期间，如果其他事务修改了相应的表，那么同一个事务的多个 SELECT 语句可能返回不同的结果。

1. READ UNCOMMITTED

> READ UNCOMMITTED 提供了事务之间最小限度的隔离。除了容易产生虚幻的读操作和不能重复的读操作外，处于这个隔离级的事务可以读到其他事务还没有提交的数据，如果这个事务使用其他事务不提交的变化作为计算的基础，然后那些未提交的变化被它们的父事务撤销，这就导致了大量的数据变化。

**在 MySQL 数据库种，默认的事务隔离级别是 REPEATABLE READ**

### 1.2 SQL 实践

接下来通过几条简单的 SQL 向读者验证上面的理论。

#### 1.2.1 查看隔离级别

通过如下 SQL 可以查看数据库实例默认的全局隔离级别和当前 session 的隔离级别：

MySQL8 之前使用如下命令查看 MySQL 隔离级别：

```sql
SELECT @@GLOBAL.tx_isolation, @@tx_isolation;
复制代码
```

查询结果如图：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/05/0937-eqxaLq.awebp)

可以看到，默认的隔离级别为 REPEATABLE-READ，全局隔离级别和当前会话隔离级别皆是如此。

**MySQL8 开始，通过如下命令查看 MySQL 默认隔离级别**：

```sql
SELECT @@GLOBAL.transaction_isolation, @@transaction_isolation;
复制代码
```

就是关键字变了，其他都一样。

通过如下命令可以修改隔离级别（建议开发者在修改时修改当前 session 隔离级别即可，不用修改全局的隔离级别）：

```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
复制代码
```

上面这条 SQL 表示将当前 session 的数据库隔离级别设置为 READ UNCOMMITTED，设置成功后，再次查询隔离级别，发现当前 session 的隔离级别已经变了，如图1-2：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/05/0937-EkpHrZ.awebp)

**注意，如果只是修改了当前 session 的隔离级别，则换一个 session 之后，隔离级别又会恢复到默认的隔离级别，所以我们测试时，修改当前 session 的隔离级别即可。**

#### 1.2.2 READ UNCOMMITTED

##### 1.2.2.1 准备测试数据

READ UNCOMMITTED 是最低隔离级别，这种隔离级别中存在**脏读、不可重复读以及幻象读**问题，所以这里我们先来看这个隔离级别，借此大家可以搞懂这三个问题到底是怎么回事。

下面分别予以介绍。

首先创建一个简单的表，预设两条数据，如下：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/05/0937-MnfRxb.awebp)

表的数据很简单，有 javaboy 和 itboyhub 两个用户，两个人的账户各有 1000 人民币。现在模拟这两个用户之间的一个转账操作。

**注意，如果读者使用的是 Navicat 的话，不同的查询窗口就对应了不同的 session，如果读者使用了 SQLyog 的话，不同查询窗口对应同一个 session，因此如果使用 SQLyog，需要读者再开启一个新的连接，在新的连接中进行查询操作。**

##### 1.2.2.2 脏读

一个事务读到另外一个事务还没有提交的数据，称之为脏读。具体操作如下：

1. 首先打开两个SQL操作窗口，假设分别为 A 和 B，在 A 窗口中输入如下几条 SQL （输入完成后不用执行）：

```sql
START TRANSACTION;
UPDATE account set balance=balance+100 where name='javaboy';
UPDATE account set balance=balance-100 where name='itboyhub';
COMMIT;
复制代码
```

1. 在 B 窗口执行如下 SQL，修改默认的事务隔离级别为 READ UNCOMMITTED，如下：

```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
复制代码
```

1. 接下来在 B 窗口中输入如下 SQL，输入完成后，首先执行第一行开启事务（注意只需要执行一行即可）：

```sql
START TRANSACTION;
SELECT * from account;
COMMIT;
复制代码
```

1. 接下来执行 A 窗口中的前两条 SQL，即开启事务，给 javaboy 这个账户添加 100 元。

1. 进入到 B 窗口，执行 B 窗口的第二条查询 SQL（SELECT * from user;），结果如下：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/05/0938-tSOr12.awebp)

可以看到，A 窗口中的事务，虽然还未提交，但是 B 窗口中已经可以查询到数据的相关变化了。

这就是**脏读**问题。

##### 1.2.2.3 不可重复读

不可重复读是指一个事务先后读取同一条记录，但两次读取的数据不同，称之为不可重复读。具体操作步骤如下（操作之前先将两个账户的钱都恢复为1000）：

1. 首先打开两个查询窗口 A 和 B ，并且将 B 的数据库事务隔离级别设置为 READ UNCOMMITTED。具体 SQL 参考上文，这里不赘述。
2. 在 B 窗口中输入如下 SQL，然后只执行前两条 SQL 开启事务并查询 javaboy 的账户：

```sql
START TRANSACTION;
SELECT * from account where name='javaboy';
COMMIT;
复制代码
```

前两条 SQL 执行结果如下：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/05/0938-VX3qnt.awebp)

1. 在 A 窗口中执行如下 SQL，给 javaboy 这个账户添加 100 块钱，如下：

```sql
START TRANSACTION;
UPDATE account set balance=balance+100 where name='javaboy';
COMMIT;
复制代码
```

4.再次回到 B 窗口，执行 B 窗口的第二条 SQL 查看 javaboy 的账户，结果如下：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/05/0938-29dGbP.awebp)

javaboy 的账户已经发生了变化，即前后两次查看 javaboy 账户，结果不一致，这就是**不可重复读**。

**和脏读的区别在于，脏读是看到了其他事务未提交的数据，而不可重复读是看到了其他事务已经提交的数据（由于当前 SQL 也是在事务中，因此有可能并不想看到其他事务已经提交的数据）。**

##### 1.2.2.4 幻象读

幻象读和不可重复读非常像，看名字就是产生幻觉了。

我举一个简单例子。

在 A 窗口中输入如下 SQL：

```sql
START TRANSACTION;
insert into account(name,balance) values('zhangsan',1000);
COMMIT;
复制代码
```

然后在 B 窗口输入如下 SQL：

```sql
START TRANSACTION;
SELECT * from account;
delete from account where name='zhangsan';
COMMIT;
复制代码
```

我们执行步骤如下：

1. 首先执行 B 窗口的前两行，开启一个事务，同时查询数据库中的数据，此时查询到的数据只有 javaboy 和 itboyhub。
2. 执行 A 窗口的前两行，向数据库中添加一个名为 zhangsan 的用户，注意不用提交事务。
3. 执行 B 窗口的第二行，由于脏读问题，此时可以查询到 zhangsan 这个用户。
4. 执行 B 窗口的第三行，去删除 name 为 zhangsan 的记录，这个时候删除就会出问题，虽然在 B 窗口中可以查询到 zhangsan，但是这条记录还没有提交，是因为脏读的原因才看到了，所以是没法删除的。此时就产生了幻觉，明明有个 zhangsan，却无法删除。

这就是**幻读**。

看了上面的案例，大家应该明白了**脏读**、**不可重复读**以及**幻读**各自是什么含义了。

#### 1.2.3 READ COMMITTED

和 READ UNCOMMITTED 相比，READ COMMITTED 主要解决了脏读的问题，对于不可重复读和幻象读则未解决。

将事务的隔离级别改为 `READ COMMITTED` 之后，重复上面关于脏读案例的测试，发现已经不存在脏读问题了；重复上面关于不可重复读案例的测试，发现不可重复读问题依然存在。

上面那个案例不适用于幻读的测试，我们换一个幻读的测试案例。

还是两个窗口 A 和 B，将 B 窗口的隔离级别改为 `READ COMMITTED`，

然后在 A 窗口输入如下测试 SQL：

```sql
START TRANSACTION;
insert into account(name,balance) values('zhangsan',1000);
COMMIT;
复制代码
```

在 B 窗口输入如下测试 SQL：

```sql
START TRANSACTION;
SELECT * from account;
insert into account(name,balance) values('zhangsan',1000);
COMMIT;
复制代码
```

测试方式如下：

1. 首先执行 B 窗口的前两行 SQL，开启事务并查询数据，此时查到的只有 javaboy 和 itboyhub 两个用户。
2. 执行 A 窗口的前两行 SQL，插入一条记录，但是并不提交事务。
3. 执行 B 窗口的第二行 SQL，由于现在已经没有了脏读问题，所以此时查不到 A 窗口中添加的数据。
4. 执行 B 窗口的第三行 SQL，由于 name 字段唯一，因此这里会无法插入。此时就产生幻觉了，明明没有 zhangsan 这个用户，却无法插入 zhangsan。

#### 1.2.4 REPEATABLE READ

和 READ COMMITTED 相比，REPEATABLE READ 进一步解决了不可重复读的问题，但是幻象读则未解决。

REPEATABLE READ 中关于幻读的测试和上一小节基本一致，不同的是第二步中执行完插入 SQL 后记得提交事务。

由于 REPEATABLE READ 已经解决了不可重复读，因此第二步即使提交了事务，第三步也查不到已经提交的数据，第四步继续插入就会出错。

**注意，REPEATABLE READ 也是 InnoDB 引擎的默认数据库事务隔离级别**

#### 1.2.5 SERIALIZABLE

SERIALIZABLE 提供了事务之间最大限度的隔离，在这种隔离级别中，事务一个接一个顺序的执行，不会发生脏读、不可重复读以及幻象读问题，最安全。

如果设置当前事务隔离级别为 SERIALIZABLE，那么此时开启其他事务时，就会阻塞，必须等当前事务提交了，其他事务才能开启成功，因此前面的脏读、不可重复读以及幻象读问题这里都不会发生。

### 1.3 总结

总的来说，隔离级别和脏读、不可重复读以及幻象读的对应关系如下：

| 隔离级别         | 脏读   | 不可重复读 | 幻象读 |
| ---------------- | ------ | ---------- | ------ |
| READ UNCOMMITTED | 允许   | 允许       | 允许   |
| READ COMMITED    | 不允许 | 允许       | 允许   |
| REPEATABLE READ  | 不允许 | 不允许     | 允许   |
| SERIALIZABLE     | 不允许 | 不允许     | 不允许 |

性能关系如图：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/05/0939-Kwk3J4.awebp)

松哥前不久也录过一个隔离级别的视频，大家可以参考下：

- [www.bilibili.com/video/BV14L…](https://link.juejin.cn?target=https%3A%2F%2Fwww.bilibili.com%2Fvideo%2FBV14L4y1B7mB)

## 

## 2. 快照读与当前读

接下来我们还需要搞明白一个问题：快照读与当前读。

### 2.1 快照读

快照读（SnapShot Read）是一种一致性不加锁的读，是 InnoDB 存储引擎并发如此之高的核心原因之一。

在可重复读的隔离级别下，事务启动的时候，就会针对当前库拍一个照片（快照），快照读读取到的数据要么就是拍照时的数据，要么就是当前事务自身插入/修改过的数据。

我们日常所用的不加锁的查询，包括本文第一小节中涉及到的所有查询，都属于快照读，这个我就不演示了。

### 2.2 当前读

与快照读相对应的就是当前读，当前读就是读取最新数据，而不是历史版本的数据，换言之，在可重复读隔离级别下，如果使用了当前读，也可以读到别的事务已提交的数据。

松哥举个例子：

MySQL 事务开启两个会话 A 和 B。

首先在 A 会话中开启事务并查询 id 为 1 的记录：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/05/0939-q8ZNJZ.awebp)



接下来我们在 B 会话中对 id 为 1 的数据进行修改，如下：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/05/0939-S03Yxv.awebp)

**注意 B 会话不要开启事务或者开启了及时提交事务，否则 update 语句占用一把排他锁会导致一会在 A 会话中用锁时发生阻塞。**

接下来，回到 A 会话中继续做查询操作，如下：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/05/0939-L8aFdb.awebp)

可以看到，A 会话中第一个查询是快照读，读取

到的是当前事务开启时的数据状态，后面两个查询则是当前读，读取到了当前最新的数据（B 会话中修改后的数据）。



## 3. undo log

我们再来稍微了解一下 undo log，这也有助于我们理解后面的 MVCC，这里我们简单介绍一下。

我们知道数据库事务有回滚的能力，既然能够回滚，那么就必须要在数据改变之前先把旧的数据记录下来，作为将来回滚的依据，那么这个记录就是 undo log。

当我们要添加一条记录的时候，就把添加的数据 id 记录到 undo log 中，将来回滚的时候就据此把数据删除；当我们要删除或者修改数据的时候，就把原数据记录到 undo log 中，将来据此恢复数据。查询操作因为不涉及回滚操作，所以就不需要记录到 undo log 中。

## 4. 行格式

接下来我们再来看一看行格式，这也有助于我们理解 MVCC。

行格式就是 InnoDB 在保存每一行的数据的时候，究竟是以什么样的格式来保存这行数据的。

数据库中的行格式有好几种，例如 COMPACT、REDUNDANT、DYNAMIC、COMPRESSED 等，不过无论是哪种行格式，都绕不开下面几个隐藏的数据列：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/05/0940-Gu57cs.awebp)

上图中的列 1、列 2、列 3 一直到列 N，就是我们数据库中表的列，保存着我们正常的数据，除了这些保存数据的列之外，还有三列额外加进来的数据，这也是我们这里要重点关注的 `DB_ROW_ID`、`DB_TRX_ID`、`DB_ROLL_PTR` 三列：

- `DB_ROW_ID`：该列占用 6 个字节，是一个行 ID，用来唯一标识一行数据。如果用户在创建表的时候没有设置主键，那么系统会根据该列建立主键索引。
- `DB_TRX_ID`：该列占用 6 个字节，是一个事务 ID。在 InnoDB 存储引擎中，当我们要开启一个事务的时候，会向 InnoDB 的事务系统申请一个事务 id，这个事务 id 是一个**严格递增且唯一的数字**，当前数据行是被哪个事务修改的，就会把对应的事务 id 记录在当前行中。
- `DB_ROLL_PTR`：该列占用 7 个字节，是一个回滚指针，这个回滚指针指向一条 undo log 日志的地址，通过这个 undo log 日志可以让这条记录恢复到前一个版本。

好啦，这是关于数据行格式的一些内容。

## 5. MVCC

有了前面小节的预备知识，接下来我们就来正式看一看 MVCC。

MVCC，英文全称是 Multi-Version Concurrency Control，中文译作多版本并发控制。

MVCC 的核心思路就是保存数据行的历史版本，通过对数据行的多个版本进行管理来实现数据库的并发控制。

简单来说，我们平时看到的一条一条的记录，在数据库中保存的时候，可能不仅仅只有一条记录，而是有多个历史版本。

如下图：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/05/0940-zWk2Wi.awebp)

这张图理解到位了，我想大家的 MVCC 也就理解的查不多了。

接下来我结合不同的隔离级别来和大家说这张图。

### 5.1 REPEATABLE READ

首先，当我们通过 INSERT\DELETE\UPDATE 去操作一行数据的时候，就会产生一个事务 id，这个事务 id 也会同时保存在行记录中（DB_TRX_ID），也就是说，当前数据行是哪个事务修改后得到的，是有记录的。

INSERT\DELETE\UPDATE 操作都会产生对应的 undo log 日志，每一行记录都有一个 `DB_ROLL_PTR` 指向 undo log 日志，每一行记录，通过执行 undo log 日志，就可以恢复到前一个记录、前前记录、前前前记录...

当我们开启一个事务的时候，首先会向 InnoDB 的事务系统申请一个事务 id，这个 id 是一个严格递增的数字，在当前事务开启的一瞬间系统会创建一个数组，数组中保存了目前所有的活跃事务 id，所谓的活跃事务就是指已开启但是还没有提交的事务。

> 这个数组中的最小值好理解，有的小伙伴可能会误以为数组中的最大值就是的当前事务的 id，其实这个不一定，也有可能更大。因为从申请到 trx_id 到创建数组之间也是需要时间的，这期间可能有其他会话也申请到了 trx_id。

当当前事务想要去查看某一行数据的时候，会先去查看该行数据的 `DB_TRX_ID`：

1. 如果这个值等于当前事务 id，说明这就是当前事务修改的，那么数据可见。
2. 如果这个值小于数组中的最小值，说明当我们开启当前事务的时候，这行数据修改所涉及到的事务已经提交了，当前数据行是可见的。
3. 如果这个值大于数组中的最大值，说明这行数据是我们在开启事务之后，还没有提交的时候，有另外一个会话也开启了事务，并且修改了这行数据，那么此时这行数据就是不可见的。
4. 如果这个值的大小介于数组中最大值最小值之间（闭区间），且该值不在数组中，说明这也是一个已经提交的事务修改的数据，这是可见的。
5. 如果这个值的大小介于数组中最大值最小值之间（闭区间），且该值在数组中（不等于当前事务 id），说明这是一个未提交的事务修改的数据，不可见。

前三种情况应该很好理解，主要是后面两种，松哥举一个简单例子。

比如我们有 A、B、C、D 四个会话，首先 A、B、C 分别开启一个事务，事务 ID 是 3、4、5，然后 C 会话提交了事务，A、B 未提交。接下来 D 会话也开启了一个事务，事务 ID 是 6，那么当 D 会话开启事务的时候，数组中的值就是 [3,4,6]。现在假设有一行数据的 `DB_TRX_ID` 是 5（第四种情况），那么该行数据就是可见的（因为当前事务开启的时候它已经提交了）；如果有一行数据的 `DB_TRX_ID` 是 4，那么该行就不可见（因为未提交）。

另外还有一个需要注意的地方，就是如果当前事务中涉及到数据的更新操作，那么更新操作是在当前读的基础上更新的，而不是快照读的基础上更新的，如果是后者则有可能导致数据丢失。

我举一个例子，假设有如下表：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/05/0940-jrMeCo.awebp)



现在有两个会话 A 和 B，首先在 A 中开启事务：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/05/0940-hICyGB.awebp)

然后在会话 B 中做一次修改操作（不用显式开启事务，更新 SQL 内部会开启事务，更新完成后事务会自动提交）：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/05/0941-k3j9PD.awebp)



接下来回到会话 A 中，查询该条记录发现值没变，符合预期（目前隔离级别是可重复读），然后在 A 中做一次修改操作，修改完成后再去查询，如下图：

![img](https://cdn.jsdelivr.net/gh/wuwenyishi/shared@image/2022/04/05/0941-Pp6UD0.awebp)

可以看到，更新其实是在 100 的基础上更新的，这个也好理解，要是在 99 的基础上更新，那么就会丢失掉 100 的那次更新，显然是不对的。

**其实 MySQL 中的 update 就是先读再更新，读的时候默认就是当前读，即会加锁。所以在上面的案例中，如果 B 会话中显式的开启了事务并且没有没有提交，那么 A 会话中的 update 语句就会被阻塞。**

这就是 MVCC，一行记录存在多个版本。实现了读写并发控制，读写互不阻塞；同时 MVCC 中采用了乐观锁，读数据不加锁，写数据只锁行，降低了死锁的概率；并且还能据此实现快照读。

### 5.2 READ COMMITTED

READ COMMITTED 和 REPEATABLE READ 类似，区别主要是后者在每次事务开始的时候创建一致性视图（创建数组列出活跃事务 id），而前者则每一个语句执行前都会重新算出一个新的视图。

所以 READ COMMITTED 这种隔离级别会看到别的会话已经提交的数据（即使别的会话比当前会话开启的晚）。

## 6. 小结

MVCC 在一定程度上实现了读写并发，不过它只在 READ COMMITTED 和 REPEATABLE READ 两个隔离级别下有效。

而 READ UNCOMMITTED 总是会读取最新的数据行，SERIALIZABLE 则会对所有读取的行都加锁，这两个都和 MVCC 不兼容。

好啦，不知道小伙伴们看明白没有，有问题欢迎留言讨论。


作者：江南一点雨
链接：[https://juejin.cn/post/7044043884694863902](https://juejin.cn/post/7044043884694863902)
来源：稀土掘金
著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。