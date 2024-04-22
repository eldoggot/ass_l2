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
    point2 point <0, 0>

    rectangle_height dw 100
    rectangle_length dw 50
DATA_SEG ends

CODE_SEG segment
ASSUME cs: CODE_SEG, ds: DATA_SEG, ss: STACK_SEG

main:
    mov ax, DATA_SEG; Сохранение адреса сегмента данных
    mov ds, ax

    mov ax, 0012h; Установка видеорежима
    int 10h

    call draw_rectangle_hollow

    mov ah, 4CH; Завершение программы
    mov al, 0
    int 21h

; Аргументы:
;   point1: левый верхний угол прямоугольника
;   rectangle_lenght: длина прямоугольника
;   rectangle_height: высота прямоугольника
; Результат:
;   Нет
; Регистры:
;   ax: промежуточные вычисления координат
draw_rectangle_hollow proc near
    push ax
    mov ax, point1.x; Сдвиг x-координаты второй точки на длину прямоугольника
    add ax, rectangle_length
    mov point2.x, ax 
    mov ax, point1.y; Обе точки лежат на одной y-координате
    mov point2.y, ax
    call draw_line_along_x; Отрисовка верхнего ребра
    
    mov ax, rectangle_height
    add point1.y, ax; Сдвиг точек по y-координате на высоту прямоугольника
    add point2.y, ax
    call draw_line_along_x; Отрисовка нижнего ребра

    mov ax, rectangle_height
    sub point1.y, ax; Возврат в левый верхний угол, т.к. процедура отрисовки может рисовать только снизу вверх
    mov ax, point1.x; Обе точки лежат на одной x-координате
    mov point2.x, ax
    call draw_line_along_y; Отрисовка левого ребра
    
    mov ax, rectangle_length
    add point1.x, ax; Сдвиг точек по x-координате на длину прямоугольника
    add point2.x, ax
    call draw_line_along_y; Отрисовка правого ребра
    pop ax
    ret
draw_rectangle_hollow endp


; Аргументы:
;   point1, point2: точки начала и конца отрезка соответственно
;   pixel_color: цвет отрезка
; Результат:
;   Нет
; Регистры:
;   ax, bx: сравнение относительного положения точек
;   si: x-координата отрисовки отрезка
;   di: y-координата отрисовки отерзка
;   cx: итератор цикла отрисовки
draw_line_along_x proc near
    push si di ax bx cx
    mov ax, point2.x
    mov bx, point1.x
    ; Сравнение относительного положения точек
    cmp ax, bx
    jg @point1_to_point2; Переход по метке, если x-координата point2 больше x-координаты point1
    jmp @point2_to_point1
    ; Отрисовка отрезка от точки point1 до point2
    @point1_to_point2:
        mov si, point1.x; point1.x - точка начала отрезка
        mov cx, point2.x
        sub cx, point1.x; cx - длина отрезка
        jmp @point_comparison_exit
    ; Отрисовка отрезка от точки point2 до point1
    @point2_to_point1:
        mov si, point2.x; point2.x - точка начала отрезка
        mov cx, point1.x
        sub cx, point2.x; cx - длина отрезка
        jmp @point_comparison_exit
    @point_comparison_exit:
    
    mov di, point1.y; y-кооридната отрезка статическая, поэтому устанавливается один раз вне цикла
    
    @draw_line_along_x_loop:
        call draw_pixel
        inc si
    loop @draw_line_along_x_loop

    pop cx bx ax di si
    ret
draw_line_along_x endp

; Аргументы:
;   point1, point2: точки начала и конца отрезка соответственно
;   pixel_color: цвет отрезка
; Результат:
;   Нет
; Регистры:
;   ax, bx: сравнение относительного положения точек
;   si: x-коориданта отрисовки отрезка
;   di: y-координата отрисовки отрезка
;   cx: итератор цикла отрисовки
draw_line_along_y proc near
    push si di ax bx cx
    mov ax, point2.y
    mov bx, point1.y
    ; Сравнение относительного положения точек
    cmp ax, bx
    jg @point1_to_point2_; Переход по метке, если y-координата point2 больше y-координаты point1
    jmp @point2_to_point1_
    ; Отрисовка отрезка от точки point1 до point2
    @point1_to_point2_:
        mov di, point1.y; point1.y - точка начала отрезка
        mov cx, point2.y
        sub cx, point1.y; cx - длина отрезка
        jmp @point_comparison_exit_
    ; Отрисовка отрезка от точки point2 до point1
    @point2_to_point1_:
        mov di, point2.y; point2.y - точка начала отрезка
        mov cx, point1.y
        sub cx, point2.y; cx - длина отрезка
        jmp @point_comparison_exit_
    @point_comparison_exit_:
    
    mov si, point1.x; x-кооридната отрезка статическая, поэтому устанавливается один раз вне цикла
    @draw_line_along_y_loop_:
        call draw_pixel
        inc di
    loop @draw_line_along_y_loop_
    
    pop cx bx ax di si
    ret
draw_line_along_y endp

; Аргументы:
;   si: x-координата рисуемого пикселя
;   di: y-координата рисуемого пикселя
;   pixel_color: цвет пикселя
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