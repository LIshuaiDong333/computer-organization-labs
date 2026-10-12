.data
float1: .float -266
float2: .float -666

.macro push %a
	addi sp, sp, -4
	sw   %a, 0(sp)
.end_macro

.macro pop %a
	lw   %a, 0(sp)
	addi sp, sp, 4
.end_macro

.macro print %a
    fmv.s.x fa0, %a  # 将整数寄存器 %a 的值移动到浮点寄存器 fa0
    ori  a7, zero, 2 # 将系统调用号 2（打印浮点数）写入 a7
    ecall            # 触发系统调用
.end_macro
.text

MAIN:
	lui t0, %hi(float1)  #高20位地址保存到t0 低12位置0
	addi t0, t0, %lo(float1) #再加上低12位地址
	lw a0,0(t0)
		    
	lui t1, %hi(float2)
	addi t1, t1, %lo(float2)	
	lw a1,0(t1)
	
	jal ra,float_add 
	
    	print a0
    	ori a7, zero, 10
    	ecall

float_add:
	push ra
    	push s0
    	push s1
    	push s2	
	
	#获取符号位并保存符号位到最高位
	srli s0, a0, 31
	slli s0, s0, 31
	
	# 获取指数位
	srli s1, a0, 23
	andi s1, s1, 0xff 
	
	srli s2, a1, 23
	andi s2, s2, 0xff
	
	# 获取尾数
	slli t0, a0, 9
	srli t0, t0, 9
	lui t1, 0x800 #0000 0000 1000 接5个0000（用来补尾码最高位的1） 
	add t0, t0, t1 
	
	slli t2, a1, 9
	srli t2, t2 ,9
	add t2, t2, t1 
	
	sub t3, s1, s2
	srl t2, t2, t3
	
	#尾数和的形成的尾数
	add t4, t2, t0
	#判断溢出
	srli t5, t4, 24 #右移24位后 尾数包括补上的1全部正好没了 如果溢出t5就是1 不溢出就是0
	andi t5, t5, 1 
	beq t5, x0, L_1
	  #溢出规格化
	  srli t4, t4, 1
	  addi s1, s1, 1
	  jal ra, L_1
	
	pop s2
	pop s1
	pop s0
    	pop ra
    	
    	jalr x0, ra, 0

L_1:    #拼接
        push ra
        push s0
    	push s1	
    	
	slli t4, t4, 9
	srli t4, t4, 9
	
	slli s1, s1, 23
	
	or a0, s1, s0
	or a0, a0, t4
	
	pop s1
	pop s0
    	pop ra
    	jalr x0, ra, 0
	
