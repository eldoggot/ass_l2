STACK_SEG segment stack
    db 256 dup(0)
STACK_SEG ends

HISTORY_SEG segment stack
    db 256 dup(0)
HISTORY_SEG ends

DATA_SEG segment
    point struc
        x dw 0
        y dw 0
    point ends
   
    pixel_color db 4
    point1 point <0, 0>
    point2 point <0, 0>

    color_panel_size dw 20
    color_panel_max_x dw 0

    x_incr dw 0
    y_incr dw 0
    err dw 0

    is_drawing_hollow dw 0
    is_drawing_filled dw 0
    is_drawing_line dw 0
DATA_SEG ends

CODE_SEG segment
ASSUME cs: CODE_SEG, ds: DATA_SEG, ss: STACK_SEG

main:
    mov ax, DATA_SEG; Сохранение адреса сегмента данных
    mov ds, ax

    mov ax, 0012h; Установка видеорежима
    int 10h

    mov ax, 0; Инициализация мыши
    int 33h
    test ax, ax; Проверка инициализации
    jz program_end; Если мышь не инициализирована, программа завершается

    mov ax, 0Ch; Установка обработчика событий иыши
    push cs
    pop es

    mov cx, 101010b; Установка кнопок мыши
    mov dx, offset mouse_handler; Адрес обработчика мыши
    int 33h

    call draw_interface

    mov ax, 1; Показать курсор мыши
    int 33h

    mov ah,0; Ожидание нажатия клавиши
    int 16h

    mov ax, 0Ch; Удаление обработчика мыши
    mov cx, 0 
    int 33h

    program_end:

    mov ah, 4CH; Завершение программы
    mov al, 0
    int 21h

mouse_handler:
    push ax bx cx dx di
    mov ax, 0900h

    cmp cx, color_panel_max_x; Если клик по y-координате вне панели цветов, переход сразу к обработчику кнопок
    jg @skip_color_choice

    cmp dx, color_panel_size; Если клик по y-координате вне панели цветов, переход сразу к обработчику кнопок
    jg @skip_color_choice

    ; Если клик произошел внутри панели цветов, формула номера цвета высчитывается по формуле: x / <размер иконки цвета>,
    ; где / есть целочисленное деление
    push dx; div использует dx для остатка, при этом в dx содержится y-координата клика, поэтому dx сохраняется на стеке
    mov ax, cx
    mov di, color_panel_size
    xor dx, dx
    div di
    mov word ptr pixel_color, 15; Цвета отрисованы в порядке убывания номера, поэтому для получения номера цвета
    sub pixel_color, al; вычитаем его из 15(т.к. всего цветов 15)
    pop dx
    jmp @exit_handler

    @skip_color_choice:
        cmp bx, 1; bx = 1 -> нажата левая кнопка
        jz @LMB_click
        cmp bx, 2; bx = 3 -> нажата правая кнопка
        jz @RMB_click
        cmp bx, 4; bx = 4 -> нажата средняя кнопка
        jz @MMB_click
        
        jmp @exit_handler; Не найдено соответствий -> выход из процедуры

    @LMB_click:
        mov bx, is_drawing_hollow
        cmp bx, 0
        jz @LMB_first_click
        jmp @LMB_second_click
        @LMB_first_click:
            mov point1.x, cx
            mov point1.y, dx
            mov word ptr is_drawing_hollow, 1
            mov word ptr is_drawing_filled, 0
            mov word ptr is_drawing_line, 0
            jmp @exit_handler
        @LMB_second_click:
            mov point2.x, cx
            mov point2.y, dx
            call draw_rectangle_hollow
            mov word ptr is_drawing_hollow, 0
            jmp @exit_handler

    @RMB_click:
        mov bx, is_drawing_filled
        cmp bx, 0
        jz @RMB_first_click
        jmp @RMB_second_click
        @RMB_first_click:
            mov point1.x, cx
            mov point1.y, dx
            mov word ptr is_drawing_hollow, 0
            mov word ptr is_drawing_filled, 1
            mov word ptr is_drawing_line, 0
            jmp @exit_handler
        @RMB_second_click:
            mov point2.x, cx
            mov point2.y, dx
            call draw_rectangle_filled
            mov word ptr is_drawing_filled, 0
            jmp @exit_handler

    @MMB_click:
        mov bx, is_drawing_line
        cmp bx, 0
        jz @MMB_first_click
        jmp @MMB_second_click
        @MMB_first_click:
            mov point1.x, cx
            mov point1.y, dx
            mov word ptr is_drawing_hollow, 0
            mov word ptr is_drawing_filled, 0
            mov word ptr is_drawing_line, 1
            jmp @exit_handler
        @MMB_second_click:
            mov point2.x, cx
            mov point2.y, dx
            call draw_line
            mov word ptr is_drawing_line, 0
            jmp @exit_handler

    @exit_handler:
        pop di dx cx bx ax
        retf

; Аргументы:
;   point1: левая точка отрезка
;   point2: правая точка отрезка
;   pixel_color: цвет отрезка
; Результат:
;   Нет
; Регистры:
;   ax, bx: сравнение относительного положения точек для оптимизации
;   ax, bx, dx: промежуточные вычисления
draw_line proc near
    push ax bx cx dx di si
    mov cx, point2.x
    mov dx, point2.y

    mov ax, cx
    sub ax, point1.x; dx = p2.x - p1.x
    jns dx_pos; Если dx < 0, x-координата отрисовки отрезка будет уменьшаться
    neg ax
    mov word ptr x_incr, 1; Если dx > 0, x-координата отрисовки отрезка будет увеличиваться
    jmp dx_neg
    dx_pos:
        mov word ptr x_incr, -1
    dx_neg:
        mov bx, dx
        sub bx, point1.y
        jns dy_pos
        neg bx
        mov word ptr y_incr, 1
        jmp dy_neg
    dy_pos:
        mov word ptr y_incr, -1
    dy_neg:
        shl ax, 1
        shl bx, 1
        call draw_pixel
        cmp ax, bx
        jna dx_less_than_dy
        mov di, ax
        shr di, 1
        neg di
        add di, bx
    draw_line_loop1:
        cmp cx, word ptr point1.x
        je exit_bres
        cmp di, 0
        jl fractlt0
        add dx, word ptr y_incr
        sub di, ax
    fractlt0:
        add cx, word ptr x_incr
        add di, bx
        call draw_pixel
        jmp draw_line_loop1
    dx_less_than_dy:
        mov di, bx
        shr di, 1
        neg di
        add di, ax
    draw_line_loop2:
        cmp dx, word ptr point1.y
        je exit_bres
        cmp di, 0
        jl fractlt02
        add cx, word ptr x_incr
        sub di, bx
    fractlt02:
        add dx, word ptr y_incr
        add di, ax
        call draw_pixel
        jmp draw_line_loop2
    exit_bres:
        pop si di cx dx bx ax
    ret
draw_line endp

; Аргументы:
;   point1: точка левого верхнего угла прямоугольника
;   point2: точка нижнего правого угла прямоугольника
;   pixel_color: цвет прямоугольника
; Результат:
;   Нет
draw_rectangle_hollow proc near
    push ax bx cx dx
    mov ax, point1.x
    mov bx, point2.x
    cmp ax, bx; Проверка на то, что x-координата левого угла меньше x-координаты правого угла
    jle @hollow_compare_y; Если это так, аналогично проверяется y-координаты
    xchg ax, bx; Иначе значения регистров меняются местами
    @hollow_compare_y:
        mov cx, point1.y
        mov dx, point2.y
        cmp cx, dx
    jle @hollow_exit_coord_confirmation; Если y-координаты адекватны, переход к следующему этапу процедуры
    xchg cx, dx
    @hollow_exit_coord_confirmation:
    ; ax = x левого верхнего угла
    ; bx = x правого нижнего угла
    ; cx = y левого верхнего угла
    ; dx = y правого нижнего угла
    call draw_line_along_x; Отрисовка верхнего ребра
    xchg cx, dx; draw_line_along_x принимает cx в качестве параметра для y-координаты отерзка
               ; ** - измененные аттрибуты
    ; ax = x левого верхнего угла
    ; bx = x правого нижнего угла
    ; cx = y *левого нижнего* угла
    ; dx = y *правого верхнего* угла
    call draw_line_along_x; Отрисовка нижнего ребра
    xchg ax, cx
    xchg bx, dx
    ; ax = *y* левого верхнего угла
    ; bx = *y* правого нижнего угла
    ; cx = *x* левого нижнего угла
    ; dx = *x* правого верхнего угла
    call draw_line_along_y; Отрисовка левого ребра
    xchg cx, dx
    ; ax = y левого верхнего угла
    ; bx = y правого нижнего угла
    ; cx = *правого верхнего* угла
    ; dx = x  *левого нижнего* угла
    call draw_line_along_y; Отрисовка правого ребра

    pop dx cx bx ax
    ret
draw_rectangle_hollow endp

; Аргументы:
;   point1: левый верхний угол прямоугольника
;   point2: правый нижний угол прямоугольника
;   pixel_color: цвет заливки и ребер прямоугольника
; Результат:
;   Нет
draw_rectangle_filled proc near
    push ax bx cx dx di
    mov ax, point1.x
    mov bx, point2.x
    cmp ax, bx; Проверка на то, что x-координата левого угла меньше x-координаты правого угла
    jle @filled_compare_y; Если это так, аналогично проверяется y-координаты
    xchg ax, bx; Иначе значения регистров меняются местами
    @filled_compare_y:
        mov cx, point1.y
        mov dx, point2.y
        cmp cx, dx
    jge @filled_exit_coord_confirmation; Если y-координаты адекватны, переход к следующему этапу процедуры
    xchg cx, dx
    @filled_exit_coord_confirmation:
    ; ax = x левого верхнего угла
    ; bx = x правого нижнего угла
    ; cx = y правого нижнего угла
    ; dx = y левого верхнего угла
    mov di, cx; В результате проверок, гарантировано cx >= dx
    sub di, dx; si = высота прямоугольника
    mov cx, di; Итератор aka высота прямоугольника
    @filled_rectangle_drawing_loop:
        call draw_line_along_x
        inc dx
    loop @filled_rectangle_drawing_loop

    pop di dx cx bx ax
    ret
draw_rectangle_filled endp

; Аргументы:
;   ax: x-коориданата точки начала отрезка
;   bx: x-координата точки конца отрезка
;   dx: y-координата отрезка
;   pixel_color: цвет отрезка
; Результат:
;   Нет
draw_line_along_x proc near
    push ax bx cx
    cmp ax, bx
    jle @draw_line_along_x_loop_init; Если ax < bx, переход на метку цикла отрисовки
    xchg ax, bx; Иначе значения регистров меняются местами
    @draw_line_along_x_loop_init:
        mov cx, ax; cx - итератор цикла отрисовки(изменяемая x-координата при отрисовке)
    @draw_line_along_x_loop:
        call draw_pixel
        cmp cx, bx; Проверка на то, что итератор достиг конца цикла(изменяемая x-координата достигла конца отрезка)
        jz @draw_line_along_x_exit
        inc cx
        jmp @draw_line_along_x_loop
    @draw_line_along_x_exit:
        pop cx bx ax
    ret
draw_line_along_x endp

; Аргументы:
;   ax: y-коориданата точки начала отрезка
;   bx: y-координата точки конца отрезка
;   cx: x-координата отрезка
;   pixel_color: цвет отрезка
; Результат:
;   Нет
draw_line_along_y proc near
    push ax bx dx
    cmp ax, bx
    jle @draw_line_along_y_loop_init; Если ax < bx, переход на метку цикла отрисовки
    xchg ax, bx; Иначе значения регистров меняются местами
    @draw_line_along_y_loop_init:
        mov dx, ax; cx - итератор цикла отрисовки(изменяемая y-координата при отрисовке)
    @draw_line_along_y_loop:
        call draw_pixel
        cmp dx, bx; Проверка на то, что итератор достиг конца цикла(изменяемая y-координата достигла конца отрезка)
        jz @draw_line_along_y_exit
        inc dx
        jmp @draw_line_along_y_loop
    @draw_line_along_y_exit:
        pop dx bx ax
    ret
draw_line_along_y endp

; Аргументы:
;   point1: точка начала отрисовки панели цветов, левый верхний угол первого цвета
;   color_panel_size: размер метки цвета в пикселях
draw_color_panel proc near
    push si cx    
    push word ptr point1.x
    push word ptr point1.y
    push word ptr point2.x
    push word ptr point2.y

    mov cl, 15; Итератор цикла, он же код цвета, см. https://en.wikipedia.org/wiki/BIOS_color_attributes для кодов цветов
    mov si, color_panel_size; 

    mov ax, point1.x
    add ax, si
    mov point2.x, ax

    mov ax, point1.y
    add ax, si
    mov point2.y, ax
    
    @color_panel_drawing_loop:
        mov pixel_color, cl
        call draw_rectangle_filled
        add point1.x, si; Сдвиг x-координат иконки следующего цвета на размер цвета
        add point2.x, si
    loop @color_panel_drawing_loop

    pop point2.y
    pop point2.x
    pop point1.y
    pop point1.x
    pop cx si
    ret
draw_color_panel endp

; Аргументы:
;   cx: x-координата рисуемого пикселя
;   dx: y-координата рисуемого пикселя
;   pixel_color: цвет пикселя
; Результат:
;   Нет
draw_pixel proc near
    push ax bx
    mov ah, 0Ch
    mov al, pixel_color; al = цвет пикселя
    mov bh, 0; bh = номер видеостраницы
    int 10h
    pop bx ax
    ret
draw_pixel endp

draw_interface proc near
    push ax
    mov ah, 0
    int 10h
        
    mov word ptr point1.x, 0; Стартовые координаты панели цветов
    mov word ptr point1.y, 0
    
    mov ax, color_panel_size
    mov di, 16
    mul di
    mov color_panel_max_x, ax; Конечная x-координата панели цветов = <кол-во цветов> * <размер иконки цвета>

    call draw_color_panel
    pop ax
    ret
draw_interface endp

CODE_SEG ends
end main