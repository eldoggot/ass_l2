STACK_SEG segment stack
    db 256 dup(0)
STACK_SEG ends

DATA_SEG segment
    point struc
        x dw 0
        y dw 0
    point ends
   
    pixel_color db 4
    point1 point <100, 100>
    point2 point <200, 450>

    rectangle_height dw 0
    rectangle_length dw 0
DATA_SEG ends

CODE_SEG segment
ASSUME cs: CODE_SEG, ds: DATA_SEG, ss: STACK_SEG

main:
    mov ax, DATA_SEG; Сохранение адреса сегмента данных
    mov ds, ax

    ; mov ax, 0012h; Установка видеорежима
    ; int 10h
    
    mov ah, 4CH; Завершение программы
    mov al, 0
    int 21h

; Аргументы:
;   si: x-координата рисуемого пикселя
;   di: y-координата рисуемого пикселя
; Результат:
;   Нет
draw_pixel proc near
    push ax bx cx dx
    mov ah, 0Ch
    mov al, pixel_color; al = цвет пикселя
    mov bh, 0; bh = номер видеостраницы
    mov cx, si; cx = x-координата пикслея
    mov dx, di; dx = y-координата пикселя
    int 10h
    pop dx cx bx ax
    ret
draw_pixel endp

; Аргументы:
;   ax: число, которое нужно вывести
; Результат:
;   Нет
print_number_to_screen proc near
    push ax si cx dx 
    mov si, 10 
    mov cx, 0    ; CX - счетчик цифр
    pushing_number_to_stack:
        mov dx, 0    ; DX - для хранения остатка от деления
        div si       ; Деление AX на 10, остаток в DX, результат в AX
        add dx,'0'   ; Преобразование остатка в символ ASCII
        push dx      ; Сохранение символа в стеке
        inc cx       ; Увеличение счетчика цифр
        cmp ax, 0     ; Проверка, закончился ли вывод всех цифр
        jnz pushing_number_to_stack        ; Если остались ещё цифры, продолжаем цикл
    printing_numbers_from_stack:
        pop dx       ; Извлечение цифры из стека
        mov ah, 02h   ; AH = 02h - функция INT 21h для вывода символа
        int 21h      ; Вывод цифры
        loop printing_numbers_from_stack      ; Повторение вывода для остальных цифр
    
    mov dx, 10; Вывод \n
    mov ah, 02h
    int 21h

    pop dx cx si ax
    ret
print_number_to_screen endp

CODE_SEG ends
end main