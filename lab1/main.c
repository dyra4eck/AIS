#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define N     4096      /* размер массива              */
#define REPS  2000      /* число проходов по массиву    */

static int data[N];

/* Генератор псевдослучайных чисел (LCG): одинаковые данные при каждом запуске,
 * поэтому профиль, собранный на тренировочном запуске, совпадает с рабочим. */
static unsigned int seed = 12345u;
static unsigned int lcg(void)
{
    seed = seed * 1103515245u + 12345u;
    return (seed >> 16) & 0x7fff;
}

/* Исследуемая функция.
 * Условия подобраны так, что статические эвристики GCC (-fguess-branch-probability)
 * ошибаются: ветви, которые они считают маловероятными или равновероятными,
 * на реальных данных выполняются почти всегда. */
__attribute__((noipa))   /* запрет межпроцедурных оптимизаций: вызов не будет вынесен из цикла */
long process(const int *a, int n)
{
    long sum = 0;
    for (int i = 0; i < n; i++) {
        int x = a[i];
        if (x < 0) {                /* эвристика: 41%,  на деле ~99%          */
            sum += -x;
            if ((x & 1) == 0)       /* эвристика: 50%,  на деле ~99.5%        */
                sum ^= x;
        } else {                    /* эвристика: 59%,  на деле ~1%           */
            sum += x * 7;
            sum = (sum << 3) | (sum >> 60);
        }
        if (x == -1000)             /* эвристика: 20%,  на деле ~98%          */
            continue;
        sum += i;
    }
    return sum;
}

static inline uint64_t tsc_start(void)
{
    unsigned hi, lo;
    asm volatile("CPUID\n\t"
                 "RDTSC\n\t"
                 "mov %%edx, %0\n\t"
                 "mov %%eax, %1\n\t"
                 : "=r"(hi), "=r"(lo) :: "%rax", "%rbx", "%rcx", "%rdx");
    return ((uint64_t)hi << 32) | lo;
}

static inline uint64_t tsc_stop(void)
{
    unsigned hi, lo;
    asm volatile("RDTSCP\n\t"
                 "mov %%edx, %0\n\t"
                 "mov %%eax, %1\n\t"
                 "CPUID\n\t"
                 : "=r"(hi), "=r"(lo) :: "%rax", "%rbx", "%rcx", "%rdx");
    return ((uint64_t)hi << 32) | lo;
}

int main(void)
{
    for (int i = 0; i < N; i++) {
        unsigned r = lcg() % 100;
        if (r == 0)       data[i] = (int)lcg();          /* 1%  : x >= 0      */
        else if (r == 1)  data[i] = -(int)lcg() - 1;     /* 1%  : x < 0, != -1000 */
        else              data[i] = -1000;               /* 98% : x == -1000  */
    }

    long result = 0;
    uint64_t t0 = tsc_start();
    for (int r = 0; r < REPS; r++)
        result += process(data, N);
    uint64_t t1 = tsc_stop();

    printf("result = %ld, cycles = %llu\n", result, (unsigned long long)(t1 - t0));
    return 0;
}
