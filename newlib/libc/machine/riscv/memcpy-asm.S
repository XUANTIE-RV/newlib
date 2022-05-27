/* Copyright (c) 2019  SiFive Inc. All rights reserved.

   This copyrighted material is made available to anyone wishing to use,
   modify, copy, or redistribute it subject to the terms and conditions
   of the FreeBSD License.   This program is distributed in the hope that
   it will be useful, but WITHOUT ANY WARRANTY expressed or implied,
   including the implied warranties of MERCHANTABILITY or FITNESS FOR
   A PARTICULAR PURPOSE.  A copy of this license is available at
   http://www.opensource.org/licenses.
*/

#if defined(__riscv_v) && (__riscv_v >= 1000000)
  #define VLDB vle8.v
  #define VSTB vse8.v
#else
  #define VLDB vlb.v
  #define VSTB vsb.v
#endif

#if __riscv_xlen == 64
  #define WORD_BYTES 8
  #define WORD_MASK 7
  #define EIGHT_WORDS_SHIFT 6
  #define EIGHT_WORDS_MASK 63
  #define LOAD_WORD ld
  #define LOAD_WORD_PAIR ldd
  #define STORE_WORD sd
  #define STORE_WORD_PAIR sdd
#else
  #define WORD_BYTES 4
  #define WORD_MASK 3
  #define EIGHT_WORDS_SHIFT 5
  #define EIGHT_WORDS_MASK 31
  #define LOAD_WORD lw
  #define LOAD_WORD_PAIR lwd
  #define STORE_WORD sw
  #define STORE_WORD_PAIR swd
#endif

#if defined(__riscv_xtheadc) || defined(__riscv_xtheade)
  #define LB_POST_INC(d, b) lbia d,(b),1,0
  #define LW_POST_INC(d, b) lwia d,(b),1,2
  #define SB_POST_INC(d, b) sbia d,(b),1,0
  #define SW_POST_INC(d, b) swia d,(b),1,2
#else
  #define LB_POST_INC(d, b) lb d,0(b);addi b,b,1
  #define LW_POST_INC(d, b) lw d,0(b);addi b,b,4
  #define SB_POST_INC(d, b) sb d,0(b);addi b,b,1
  #define SW_POST_INC(d, b) sw d,0(b);addi b,b,4
#endif

#if defined(__riscv_32e)
  #define REG_A6 a4
  #define REG_A7 a5
#else
  #define REG_A6 a6
  #define REG_A7 a7
#endif

.text
.align 2
.global memcpy
.type	memcpy, @function
memcpy:
#if defined(PREFER_SIZE_OVER_SPEED) || defined(__OPTIMIZE_SIZE__)
	mv	t1, a0
	beqz	a2, 2f

1:
	lb	t2, 0(a1)
	sb	t2, 0(t1)
	add	a2, a2, -1
	add	t1, t1, 1
	add	a1, a1, 1
	bnez	a2, 1b

2:
	ret
#else
#if __riscv_xlen == 64 && defined(__riscv_vector)
	mv	a3, a0
	sltiu	a4, a2, 16
	bnez	a4, .loop_cpy
	andi	a5, a0, 15
	li	a6, 16
	beqz	a5, .loop_cpy
	sub	a5, a6, a5
	vsetvli	t0, a5, e8, m4
	VLDB	v0, (a1)
	add	a1, a1, t0
	sub	a2, a2, t0
	VSTB	v0, (a3)
	add	a3, a3, t0
.loop_cpy:
	vsetvli	t0, a2, e8, m4
	VLDB	v0, (a1)
	add	a1, a1, t0
	sub	a2, a2, t0
	VSTB	v0, (a3)
	add	a3, a3, t0
	bnez	a2, .loop_cpy
	ret
#else
	/* Test if len less than word bytes.  */
	sltiu	a3, a2, WORD_BYTES
	mv	t0, a0
	add	t1, a0, a2
	bnez	a3, .L_copy_by_byte

	/* Test if dest and src have same word tail.  */
	xor	a3, a0, a1
	andi	a3, a3, WORD_MASK
	bnez	a3, .L_copy_by_byte

	andi	a3, a0, WORD_MASK
	li	t2, WORD_BYTES
	/* Test if dest is not word bytes aligned.  */
	bnez	a3, .L_dest_not_aligned
.L_dest_aligned:
	/* If dest is aligned, then copy.  */
	andi	t2, t1, -WORD_BYTES
	addi	t1, t2, -8 * WORD_BYTES
	/* Test if len less than 8 words.  */
	bgtu	a0, t1, .L_len_less_8words
	andi	a2, a2, EIGHT_WORDS_MASK
	.align 2
.L_len_larger_8words:
#if defined(__riscv_xtheadc)
	LOAD_WORD_PAIR	a4, a5, 0(a1)
	STORE_WORD_PAIR	a4, a5, 0(a0)
	LOAD_WORD_PAIR	a6, a7, 2*WORD_BYTES(a1)
	STORE_WORD_PAIR	a6, a7, 2*WORD_BYTES(a0)
	LOAD_WORD_PAIR	a4, a5, 4*WORD_BYTES(a1)
	STORE_WORD_PAIR	a4, a5, 4*WORD_BYTES(a0)
	LOAD_WORD_PAIR	a6, a7, 6*WORD_BYTES(a1)
	addi    a1, a1, 8*WORD_BYTES
	STORE_WORD_PAIR	a6, a7, 6*WORD_BYTES(a0)
#else
	LOAD_WORD	a4, 0(a1)
	STORE_WORD	a4, 0(a0)
	LOAD_WORD	a5, WORD_BYTES(a1)
	STORE_WORD	a5, WORD_BYTES(a0)
	LOAD_WORD	REG_A6, 2*WORD_BYTES(a1)
	STORE_WORD	REG_A6, 2*WORD_BYTES(a0)
	LOAD_WORD	REG_A7, 3*WORD_BYTES(a1)
	STORE_WORD	REG_A7, 3*WORD_BYTES(a0)
	LOAD_WORD	a4, 4*WORD_BYTES(a1)
	STORE_WORD	a4, 4*WORD_BYTES(a0)
	LOAD_WORD	a5, 5*WORD_BYTES(a1)
	STORE_WORD	a5, 5*WORD_BYTES(a0)
	LOAD_WORD	REG_A6, 6*WORD_BYTES(a1)
	STORE_WORD	REG_A6, 6*WORD_BYTES(a0)
	LOAD_WORD	REG_A7, 7*WORD_BYTES(a1)
	addi	a1, a1, 8*WORD_BYTES
	STORE_WORD	REG_A7, 7*WORD_BYTES(a0)
#endif
	addi	a0, a0, 8*WORD_BYTES
	bleu	a0, t1, .L_len_larger_8words

.L_len_less_8words:
#if __riscv_xlen == 64
	andi	t2, t1, -WORD_BYTES
#endif
	addi	t1, t2, -WORD_BYTES
	bgtu	a0, t1, .L_copy_by_byte_rec
	andi	a2, a2, 3
.L_len_less_8words_loop:
	LW_POST_INC(a4, a1)
	SW_POST_INC(a4, a0)
	bleu	a0, t1, .L_len_less_8words_loop

	/* Copy tail.  */
.L_copy_by_byte_rec:
	add	t1, a0, a2
.L_copy_by_byte:
	beqz	a2, .L_return
	.align 2
.L_copy_by_byte_loop:
	LB_POST_INC(a4, a1)
	SB_POST_INC(a4, a0)
	bltu	a0, t1, .L_copy_by_byte_loop

.L_return:
	mv	a0, t0
	ret

	/* If dest is not aligned, just copying some bytes makes the dest
	   align.  */
.L_dest_not_aligned:
	sub	a3, t2, a3
	mv	t2, a3
.L_dest_not_aligned_loop:
	/* Makes the dest align.  */
	LB_POST_INC(a4, a1)
	addi	a3, a3, -1
	SB_POST_INC(a4, a0)
	bnez	a3, .L_dest_not_aligned_loop
	sub	a2, a2, t2
	sltiu	a3, a2, 2
	bnez	a3, .L_copy_by_byte
	/* Check whether the src is aligned.  */
	j	.L_dest_aligned
#endif
#endif
  .size	memcpy, .-memcpy

