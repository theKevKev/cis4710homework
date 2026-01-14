        .section .data
input_string:   .asciz "Hello world!"

        # tohost/fromhost are data locations used by Spike
        .align 8
tohost: .byte 0
        .align 8
fromhost: .byte 0

        
        .section .text
        .globl _start
_start:
        # Load the address of the input string into a0
        la a0, input_string

        # Your code here!
        loop: 
                # if null character then jump end
                lb a1, 0(a0) # a1 contains "H"
                beqz a1, end_program 

                # if not ascii or already capitalized (<97 or >122)
                li a2, 0x61 # 97
                blt a1, a2, incr
                li a2, 0x7A # 122
                bgt a1, a2, incr

                # else switch to capitalized version 
                addi a1, a1, -0x20
                sb a1, 0(a0)

        incr: 
                # then move pointer by one
                addi a0, a0, 0x1
                j loop
                
end_program:
        # jump here when you're done
        j end_program

