# 1 "main.c"
# 1 "<built-in>"
# 1 "<command-line>"
# 1 "main.c"

# 1 "func.h" 1
typedef unsigned int uint32;

uint32 fadd(uint32 num1, uint32 num2)
{
    uint32 sign1 = (num1 & 0x80000000) >> 31;
    uint32 sign2 = (num2 & 0x80000000) >> 31;
    uint32 exp1 = (num1 & 0x7f800000) >> 23;
    uint32 exp2 = (num2 & 0x7f800000) >> 23;
    uint32 mant1 = (num1 & 0x007fffff);
    uint32 mant2 = (num2 & 0x007fffff);

    mant1 |= 0x00800000;
    mant2 |= 0x00800000;

    uint32 exp_delta = exp1 - exp2;
    mant2 >>= exp_delta;

    uint32 sign = sign1;
    uint32 exp = exp1;
    uint32 mant = mant1 + mant2;

    if ((mant & 0xff000000) != 0)
    {
        mant >>= 1;
        exp += 1;
    }

    mant &= 0x007fffff;

    uint32 result = (sign << 31) | (exp << 23) | mant;
    return result;
}
# 3 "main.c" 2




int main()
{
    uint32 result = fadd(0xc11c6e98, 0xbf9df3b6);


    return 0;
}
