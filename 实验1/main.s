	.file	"main.c"
	.option nopic
	.attribute arch, "rv32i2p0_m2p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.align	2
	.globl	fadd
	.type	fadd, @function
fadd:
	addi	sp,sp,-80
	sw	s0,76(sp)
	addi	s0,sp,80
	sw	a0,-68(s0)
	sw	a1,-72(s0)
	lw	a5,-68(s0)
	srli	a5,a5,31
	sw	a5,-28(s0)
	lw	a5,-72(s0)
	srli	a5,a5,31
	sw	a5,-32(s0)
	lw	a5,-68(s0)
	srli	a5,a5,23
	andi	a5,a5,255
	sw	a5,-36(s0)
	lw	a5,-72(s0)
	srli	a5,a5,23
	andi	a5,a5,255
	sw	a5,-40(s0)
	lw	a4,-68(s0)
	li	a5,8388608
	addi	a5,a5,-1
	and	a5,a4,a5
	sw	a5,-44(s0)
	lw	a4,-72(s0)
	li	a5,8388608
	addi	a5,a5,-1
	and	a5,a4,a5
	sw	a5,-48(s0)
	lw	a4,-44(s0)
	li	a5,8388608
	or	a5,a4,a5
	sw	a5,-44(s0)
	lw	a4,-48(s0)
	li	a5,8388608
	or	a5,a4,a5
	sw	a5,-48(s0)
	lw	a4,-36(s0)
	lw	a5,-40(s0)
	sub	a5,a4,a5
	sw	a5,-52(s0)
	lw	a5,-52(s0)
	lw	a4,-48(s0)
	srl	a5,a4,a5
	sw	a5,-48(s0)
	lw	a5,-28(s0)
	sw	a5,-56(s0)
	lw	a5,-36(s0)
	sw	a5,-20(s0)
	lw	a4,-44(s0)
	lw	a5,-48(s0)
	add	a5,a4,a5
	sw	a5,-24(s0)
	lw	a4,-24(s0)
	li	a5,-16777216
	and	a5,a4,a5
	beq	a5,zero,.L2
	lw	a5,-24(s0)
	srli	a5,a5,1
	sw	a5,-24(s0)
	lw	a5,-20(s0)
	addi	a5,a5,1
	sw	a5,-20(s0)
.L2:
	lw	a4,-24(s0)
	li	a5,8388608
	addi	a5,a5,-1
	and	a5,a4,a5
	sw	a5,-24(s0)
	lw	a5,-56(s0)
	slli	a4,a5,31
	lw	a5,-20(s0)
	slli	a5,a5,23
	or	a5,a4,a5
	lw	a4,-24(s0)
	or	a5,a4,a5
	sw	a5,-60(s0)
	lw	a5,-60(s0)
	mv	a0,a5
	lw	s0,76(sp)
	addi	sp,sp,80
	jr	ra
	.size	fadd, .-fadd
	.align	2
	.globl	main
	.type	main, @function
main:
	addi	sp,sp,-32
	sw	ra,28(sp)
	sw	s0,24(sp)
	addi	s0,sp,32
	li	a5,-1080168448
	addi	a1,a5,950
	li	a5,-1055100928
	addi	a0,a5,-360
	call	fadd
	sw	a0,-20(s0)
	li	a5,0
	mv	a0,a5
	lw	ra,28(sp)
	lw	s0,24(sp)
	addi	sp,sp,32
	jr	ra
	.size	main, .-main
	.ident	"GCC: (GNU) 10.2.0"
