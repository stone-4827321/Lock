//
//  ViewController.m
//  Lock
//
//  Created by stone on 2020/9/10.
//  Copyright © 2020 3kMac. All rights reserved.
//

#import "ViewController.h"
#import <os/lock.h>
#import <libkern/OSAtomic.h>
#import <pthread.h>

@interface ViewController ()

@property (atomic) int ticketsCount;

@property (nonatomic, strong) NSMutableArray *testArray;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    NSLog(@"%@",self.testArray);
}

- (void)testThreadArray
{
    @synchronized (self) {
        self.testArray = @[].mutableCopy;
    }
}

//卖票
- (void)sellingTickets {
    int oldMoney = self.ticketsCount;
    sleep(.2);
    oldMoney -= 1;
    self.ticketsCount = oldMoney;
    NSLog(@"当前剩余票数-> %d", oldMoney);
}




- (IBAction)noLock:(id)sender {
    self.ticketsCount = 50;
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    
    for (NSInteger i = 0; i < 5; i++) {
        dispatch_async(queue, ^{
            for (int i = 0; i < 10; i++) {
                [self sellingTickets];
            }
        });
    }
}

- (IBAction)OSSpinLock:(id)sender {
    self.ticketsCount = 50;
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    
    static OSSpinLock lock;
   lock = OS_SPINLOCK_INIT;
    
    for (NSInteger i = 0; i < 5; i++) {
        dispatch_async(queue, ^{
            for (int i = 0; i < 10; i++) {
                OSSpinLockLock(&lock);
                [self sellingTickets];
                OSSpinLockUnlock(&lock);
            }
        });
    }
}


- (IBAction)os_unfair_lock:(id)sender {
    self.ticketsCount = 50;
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    
    static os_unfair_lock lock;
    lock = OS_UNFAIR_LOCK_INIT;

    for (NSInteger i = 0; i < 5; i++) {
        dispatch_async(queue, ^{
            for (int j = 0; j < 10; j++) {
                os_unfair_lock_lock(&lock);
                //os_unfair_lock_lock(&lock);
                [self sellingTickets];
                os_unfair_lock_unlock(&lock);
            }
        });
    }
}


- (IBAction)pthread_mutex1:(id)sender {
    self.ticketsCount = 50;
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    
    static pthread_mutex_t lock;
    
    // 静态初始化
    //lock = PTHREAD_MUTEX_INITIALIZER;
    
    // 动态初始化
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_DEFAULT);
    pthread_mutex_init(&(lock), &attr);
    pthread_mutexattr_destroy(&attr);
    
    for (NSInteger i = 0; i < 5; i++) {
        dispatch_async(queue, ^{
            for (int j = 0; j < 10; j++) {
                pthread_mutex_lock(&lock);
                [self sellingTickets];
                pthread_mutex_unlock(&lock);
            }
        });
    }
}

- (IBAction)pthread_mutex2:(id)sender {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    pthread_mutex_t pthreadMutex;
    pthread_cond_t cond;
    pthread_mutex_init(&pthreadMutex, NULL);
    pthread_cond_init(&cond, NULL);
    __block int count = 0;
    
    while (1) {
        // 消费者
        dispatch_async(queue, ^{
            //            sleep(2);
            pthread_mutex_lock(&pthreadMutex);
//            pthread_cond_wait(&cond, &pthreadMutex);
            while (!count) {
                // 阻塞消费者线程
                pthread_cond_wait(&cond, &pthreadMutex);
            }
            count --;
            NSLog(@"消费后%d", count);
            pthread_mutex_unlock(&pthreadMutex);
        });
        // 生产者
        dispatch_async(queue, ^{
            //            sleep(1);
            pthread_mutex_lock(&pthreadMutex);
            count ++;
            NSLog(@"生产后%d",count);
            // 唤醒一个消费者线程
            pthread_cond_signal(&cond);
            pthread_mutex_unlock(&pthreadMutex);
        });
    }
}

- (IBAction)NSLock1:(id)sender {
    self.ticketsCount = 50;
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    
    static NSLock *lock;
    lock = [[NSLock alloc] init];

    for (NSInteger i = 0; i < 5; i++) {
        dispatch_async(queue, ^{
            for (int j = 0; j < 10; j++) {
                [lock lock];
                [self sellingTickets];
                [lock unlock];
            }
        });
    }
}

- (IBAction)NSLock2:(id)sender {
    self.ticketsCount = 50;
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    
    static NSLock *lock;
    lock = [[NSLock alloc] init];
    
    for (NSInteger i = 0; i < 5; i++) {
        dispatch_async(queue, ^{
            for (int j = 0; j < 10; j++) {
                NSLog(@"time");
                if ([lock tryLock]) {
                //if ([lock lockBeforeDate:[NSDate dateWithTimeIntervalSinceNow:5]]) {
                    [self sellingTickets];
                    [lock unlock];
                }
                else {
                    NSLog(@"卡住了，不卖了");
                }
            }
        });
    }
}

- (IBAction)NSRecursiveLock:(id)sender {
    self.ticketsCount = 50;
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    
    static NSRecursiveLock *lock;
    lock = [[NSRecursiveLock alloc] init];

    for (NSInteger i = 0; i < 5; i++) {
        dispatch_async(queue, ^{
            for (int j = 0; j < 10; j++) {
                [lock lock];
                [self sellingTickets];
                [lock unlock];
            }
        });
    }
}

- (IBAction)NSCondition:(id)sender {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    NSCondition *lock = [[NSCondition alloc] init];
    __block int count = 0;

    while (1) {
        // 消费者
        dispatch_async(queue, ^{
//            sleep(2);
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
//            sleep(1);
            [lock lock];
            count ++;
            NSLog(@"生产后%d",count);
            // 唤醒一个消费者线程
            [lock signal];
            [lock unlock];
        });
    }
}

- (IBAction)NSConditionLock:(id)sender {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    __block int count = 0;
    NSConditionLock *lock = [[NSConditionLock alloc] initWithCondition:0];
    
    while (1) {
        // 消费者
        dispatch_async(queue, ^{
            //            sleep(2);
            [lock lockWhenCondition:1];
            count --;
            NSLog(@"消费后%d", count);
            [lock unlockWithCondition:count ? 1 : 0];
        });
        // 生产者
        dispatch_async(queue, ^{
            //            sleep(1);
            [lock lock];
            count ++;
            NSLog(@"生产后%d",count);
            // 唤醒一个消费者线程
            [lock unlockWithCondition:count ? 1 : 0];
        });
    }
}

- (IBAction)pthread_rwlock_t:(id)sender {
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
    pthread_rwlock_destroy(&lock);
}

- (IBAction)dispatch_barrier_async:(id)sender {
//    // 必须使用自定义队列
//    dispatch_queue_t queue = dispatch_queue_create("concurrentQueue", DISPATCH_QUEUE_CONCURRENT);
//    //dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//    __block BOOL write;
//    __block BOOL read;
//
//    while (1) {
//        dispatch_async(queue, ^{
//            if (read) {
//                NSLog(@"1");
//            }
//            read = YES;
//            if (write) {
//                NSLog(@"2");
//            }
//            NSLog(@"读 %@",[NSThread currentThread]);
//            read = NO;
//        });
//        dispatch_barrier_async(queue, ^{
//            write = YES;
//            NSLog(@"写 %@",[NSThread currentThread]);
//            write = NO;
//        });
//    }
    
    dispatch_queue_t queue = dispatch_queue_create("test", DISPATCH_QUEUE_SERIAL);
    dispatch_sync(queue, ^{
    // 追加任务1
    for (int i = 0; i < 2; ++i) {
    NSLog(@"1---%@",[NSThread currentThread]);
    }
    });

    dispatch_sync(queue, ^{
    // 追加任务2
    for (int i = 0; i < 2; ++i) {
    NSLog(@"2---%@",[NSThread currentThread]);
    }
    });

}


@end
