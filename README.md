# Lock

## 概述

- 在多线程编程时，需要将线程不安全的代码 “锁” 起来。保证一段代码或者多段代码操作的原子性，保证多个线程对同一个数据的访问**同步 (Synchronization)**。

## 原子性

- 原子操作是指不会被线程调度机制打断的操作；这种操作一旦开始，就一直运行到结束，中间不会有任何上下文切换。

- 在属性关键字里设置 `atomic` 之后，默认生成的 getter 和 setter 方法执行是原子的。但是它只保证了自身的读/写操作，却不能说是线程安全。

- 以下代码中：即使将 number 声明为 `atomic`，最后的结果也不一定会是20000。虽然 getter 和 setter 是原子操作，但整个 `self.number = self.number + 1;` 语句并不是原子的，这行赋值的代码至少包含读取、+1、赋值三步操作，当前线程赋值的时候可能其他线程已经执行了若干次赋值了，导致最后的值小于预期值。这种场景就是多线程不安全。

  ```objective-c
  @property (atomic, assign) int number;
  
  //thread A
  for (int i = 0; i < 10000; i ++) {
      self.number = self.number + 1;
      NSLog(@"Thread A: %d\n", self.number);
  }
  
  //thread B
  for (int i = 0; i < 10000; i ++) {
      self.number = self.number + 1;
      NSLog(@"Thread B: %d\n", self.number);
  }
  ```

- **在做多线程安全的时候，并不是通过给 property 加 `atomic` 关键字来保障安全，而是将 property 声明为`nonatomic`（没有 getter，setter 的锁开销），然后自己加锁**。

## 自旋锁

- 自旋锁属于 **busy-waiting** 类型的锁。存在一个线程间共享的标记变量，当某个线程进入临界区后，变量被标记，此时其他线程再想进入临界区，会进入 `while` 循环中空转等待。

  ```c++
  bool lock = false; // 一开始没有锁上，任何线程都可以申请锁
  do {
      while(test_and_set(&lock); // test_and_set 是一个原子操作
          Critical section  // 临界区
      lock = false; // 相当于释放锁，这样别的线程可以进入临界区
          Reminder section // 不需要锁保护的代码        
  }
  ```

- 自旋锁的开销主要在：如果临界区需要执行较长时间，空转的代码会导致 CPU 在等待期间是满负荷执行的。

### OSSpinLock

- `OSSpinLock` 由于存在优先级反转问题，已经在 iOS10 中被废弃。

  > 自旋锁都存在的问题：如果一个低优先级的线程获得锁并访问共享资源，这时一个高优先级的线程也尝试获得这个锁，它会处于 spin lock 的忙等状态从而占用大量 CPU。此时低优先级线程无法与高优先级线程争夺 CPU 时间，从而导致任务迟迟完不成、无法释放 lock。

## 互斥锁

- 互斥锁属于 **sleep-waiting** 类型的锁。存在一个线程间共享的标记变量，当某个线程进入临界区后，变量被标记，此时其他线程再想进入临界区，会进入休眠等待状态。

- 互斥锁的开销主要在：环境切换和休眠唤醒。

- **互斥锁和自旋锁的区别：其实就是线程的区别，线程尝试获取锁但没有获取到时，互斥锁的线程会进入休眠状态，等锁被释放时，线程会被唤醒；而自旋锁的线程则会一直处于等待状态，忙等待，不会进入休眠。**

- **互斥锁又分为递归锁和非递归锁**：
  - 递归锁是一种可以多次被同一线程持有的锁，会记录上锁和解锁的次数，当二者平衡的时候，才会释放锁，其它线程才可以上锁成功。
  - 非递归锁是只能一个线程锁定一次，想要再次锁定，就必须先要解锁，否则线程会因为等待锁的释放而进入睡眠状态，就不可能再释放锁，从而导致死锁。

### os_unfair_lock

- 非递归锁。

- 用于取代不安全的`OSSpinLock`，从 iOS10 开始支持。 

  ```objective-c
  #import <os/lock.h>
  
  // 初始化
  os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;
  // 加锁
  os_unfair_lock_lock(&lock);
  // 解锁
  os_unfair_lock_unlock(&lock);
  ```

### pthread_mutex

- 由 pthread 提供一组跨平台的锁方案，除了创建互斥锁，还可以创建递归锁、读写锁、once 等锁。

- 初始化方式分为静态和动态两种方式。

  ```objective-c
  #import <pthread.h>
  
  // 静态初始化
  pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
  
  // 动态初始化
  pthread_mutex_t mutex;
  pthread_mutexattr_t attr;
  pthread_mutexattr_init(&attr);
  pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_DEFAULT);
  pthread_mutex_init(&(mutex_t), &attr);
  pthread_mutexattr_destroy(&attr);
  
  // 加锁
  pthread_mutex_lock(&mutex);
  // 解锁
  pthread_mutex_unlock(&mutex);
  // 销毁锁
  pthread_mutex_destroy(&mutex);
  ```

- 动态初始化时，可以为对属性 attr 进行相关配置：

  - 类型

    ```c++
    int pthread_mutexattr_settype(pthread_mutexattr_t *, int);
    
    #define PTHREAD_MUTEX_NORMAL        0   //一般的锁
    #define PTHREAD_MUTEX_ERRORCHECK    1   //错误检测
    #define PTHREAD_MUTEX_RECURSIVE     2   //递归锁
    #define PTHREAD_MUTEX_DEFAULT       PTHREAD_MUTEX_NORMAL    //默认
    ```

  - 协议，可解决优先级反转

    ```c++
    int pthread_mutexattr_setprotocol(pthread_mutexattr_t *, int);
    
    #define PTHREAD_PRIO_NONE            0	//线程的优先级和调度不会受到互斥锁拥有权的影响
    #define PTHREAD_PRIO_INHERIT         1	//持有该锁的线程会继承当前争用该锁的最高优先级线程的优先级
    #define PTHREAD_PRIO_PROTECT         2	//持有该锁的线程会继承锁可配置的最高优先级
    ```

  - 条件
    - `pthread_cond_wait()`：等待信号的到来，此时线程会进入休眠状态并且放开锁，等待信号到来的时候会被唤醒并加锁；
    - `pthread_cond_signal()`：发送信号，唤醒一个正在等待的线程；
    - `pthread_cond_broadcast()`：发送信号，唤醒所有正在等待的线程；
    - `pthread_cond_destroy()`：销毁条件。

### NSLock

- 非递归锁，遵守 `NSLocking` 协议。

  ```objective-c
  @protocol NSLocking
  // 加锁  
  - (void)lock;
  // 解锁
  - (void)unlock;
  @end
  ```

- 对 `pthread_mutex` 锁的简单封装，不设置属性 `pthread_mutex_init(mutex, nil)`。

- 尝试加锁且不会堵塞线程：`tryLock` 尝试加锁，如果失败的话返回 NO，`lockBeforeDate:` 是在指定时间之前尝试加锁，如果在指定时间之前都不能加锁，则返回NO。

### NSRecursiveLock

- 递归锁，遵守 `NSLocking` 协议，用法和 `NSLock` 完全一致。

- 对 `pthread_mutex` 锁的简单封装，设置属性 `pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);`。

### NSCondition

- 非递归锁，遵守 `NSLocking` 协议，`NSLock` 升级版，在加解锁的基础上增加等待和激活的方法（使用 pthread_mutex 条件）：

  - 等待：阻塞当前线程，直到接收到激活信号为止；
  - 激活：发出激活信号，唤醒一个或所有等待线程。

  ```objective-c
  NSCondition *lock = [[NSCondition alloc] init];
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  __block int count = 0;
  
  while (1) {
      // 消费者
      dispatch_async(queue, ^{
          [lock lock];
          while (!count) {
              // 阻塞消费者线程
              [lock wait];
          }
          count --;
          NSLog(@"消费后%d", count);
          [lock unlock];
      });
      // 生产者
      dispatch_async(queue, ^{
          [lock lock];
          count ++;
          NSLog(@"生产后%d",count);
          // 唤醒一个消费者线程
          [lock signal];
        	// 唤醒所有消费者线程
        	//[lock broadcast];
          [lock unlock];
      });
  }
  ```


### NSConditionLock 

- 非递归锁，遵守 `NSLocking` 协议，`NSConditionLock` 升级版，可以让线程仅在满足特定条件时才能获取锁（`_condition_value` 属性）：

  - `initWithCondition:` 初始化并且设置状态值 condition；
  - `lockWhenCondition:` 当状态值为 condition 的时候加锁；
  - `unlockWithCondition:` 解锁并设置状态值为 condition；

  ```objective-c
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  __block int count = 0;
  NSConditionLock *lock = [[NSConditionLock alloc] initWithCondition:0];
      
  while (1) {
      // 消费者
      dispatch_async(queue, ^{
          [lock lockWhenCondition:1];
          count --;
          NSLog(@"消费后%d", count);
        	// 还有剩余则以1解锁，保证消费者可以立即进来，否则以0解锁，只能生产者进来
          [lock unlockWithCondition:count ? 1 : 0];
      });
      // 生产者
      dispatch_async(queue, ^{
          [lock lock];
          count ++;
          NSLog(@"生产后%d",count);
          [lock unlockWithCondition:count ? 1 : 0];
      });
  }
  ```

### @synchronized

- 对象锁，互斥型，可递归（基于 `mutex`）。

- 使用简单，基本上是在开发中使用最频繁的锁。

  ```objective-c
  @synchronized(object) {
      // 需要加锁的代码块
  }
  ```

- synchronized 中传入的 object 的内存地址，被用作 key，通过 hash map 对应的一个系统维护的递归锁。

  - `@synchronized(nil)` 不起任何作用。

## 信号量

- 信号量为 GCD 中的 `dispatch_semaphore`。
- 信号量和互斥量的区别：
  - 一个互斥量只能用于一个资源的互斥访问不能实现多个资源的多线程互斥问题。
  - 一个信号量可以实现多个同类资源的多线程互斥和同步。当信号量为单值信号量时，也可以完成一个资源的互斥访问。


## 读写锁

- 当多个线程操作一个文件的时候，如果同时进行读写的话，会造成读的内容不完全等问题。一种方案是使用互斥锁，但此时即使是读出数据（相当于操作临界区资源）都要上互斥锁。更加优化的方案应该是**利用读写锁实现多读单写**——在同一时间可以有多条线程在读取文件内容，但是只能有一条线程执行写文件的操作。

###  pthread_rwlock_t

- `pthread_rwlock_t` 是由 pthread 提供读写锁方案。

  ```objective-c
  dispatch_queue_t queue1 = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_queue_t queue2 = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  // 初始化
  pthread_rwlock_t lock;
  pthread_rwlock_init(&lock, NULL);
      
  while (1) {
      dispatch_async(queue1, ^{
          // 读加锁
          pthread_rwlock_rdlock(&lock);
          sleep(1);
          NSLog(@"读");
          // 解锁
          pthread_rwlock_unlock(&lock);
      });
      dispatch_async(queue2, ^{
          // 写加锁
          pthread_rwlock_wrlock(&lock);
          sleep(0.5);
          NSLog(@"写");
          // 解锁
          pthread_rwlock_unlock(&lock);
      });
  }
  
  // 销毁锁
  pthread_rwlock_destroy(&lock);
  ```

- 读写锁的另外一个实现方案就是使用 GCD 的 `dispatch_barrier_async`

  ```objective-c
  dispatch_queue_t queue = dispatch_queue_create("concurrentQueue", DISPATCH_QUEUE_CONCURRENT);
  
  while (1) {
      dispatch_async(queue, ^{
          NSLog(@"读");
      });
      dispatch_barrier_async(queue, ^{
          NSLog(@"写");
      });
  }
  ```


## 性能比较

![](/Users/3kmac/Desktop/我的文档/图片/Lock_性能比较.png)