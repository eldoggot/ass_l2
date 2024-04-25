STACK_SEG segment stack
    db 256 dup(0)
STACK_SEG ends

DATA_SEG segment
    point struc
        x dw 0
        y dw 0
    point ends
   
    pixel_color db 4
    point1 point <0, 0>
    point2 point <250, 250>

    rectangle_height dw 100
    rectangle_length dw 100

    color_panel_size dw 20
    color_panel_max_x dw 0

    x_incr dw 0
    y_incr dw 0
    err dw 0
DATA_SEG ends

CODE_SEG segment
ASSUME cs: CODE_SEG, ds: DATA_SEG, ss: STACK_SEG

main:
    mov ax, DATA_SEG; Сохранение адреса сегмента данных
    mov ds, ax

    mov ax, 0012h; Установка видеорежима
    int 10h

    mov word ptr point1.x, 0; Стартовые координаты панели цветов
    mov word ptr point1.y, 0
    
    mov ax, color_panel_size
    mov di, 16
    mul di
    mov color_panel_max_x, ax; Конечная x-координата панели цветов = <кол-во цветов> * <размер иконки цвета>

    call draw_color_panel

    mov word ptr pixel_color, 4
    mov word ptr rectangle_length, 150
    mov word ptr rectangle_height, 75

    mov ax, 0; Инициализация мыши
    int 33h
    test ax, ax; Проверка инициализации
    jz program_end; Если мышь не инициализирована, программа завершается

    mov ax, 0Ch; Установка обработчика событий иыши
    push cs
    pop es

    mov cx, 001010b; Установка кнопок мыши
    mov dx, offset mouse_handler; Адрес обработчика мыши
    int 33h

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
    push cx dx
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

    jmp @exit_handler

    @LMB_click:
        mov point1.x, cx
        mov point1.y, dx
        call draw_rectangle_hollow
        jmp @exit_handler

    @RMB_click:
        mov point1.x, cx
        mov point1.y, dx
        call draw_rectangle_filled
        jmp @exit_handler
    
    @exit_handler:
        pop dx cx
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
    mov ax, point1.x
    mov bx, point2.x
    cmp ax, bx; Если точки лежат на одной x-координате, вызывается специальная процедура 
    je @points_on_the_same_x
    
    mov ax, point1.y
    mov bx, point2.y
    cmp ax, bx; Если точки лежат на одной y-координате, вызывается специальная процедура 
    je @points_on_the_same_y
    jmp @points_are_scattered
    
    @points_on_the_same_x:
        call draw_line_along_y; x-координата неизменна, так что вызывается процедура отрисовки вдоль y-координаты
        jmp @draw_line_exit

    @points_on_the_same_y:
        call draw_line_along_x; y-координата неизменна, так что вызывается процедура отрисовки вдоль x-координаты
        jmp @draw_line_exit

    @points_are_scattered:
        mov si, point2.x
        mov di, point2.y

        mov ax, point2.x
        sub ax, point1.x; dx = p2.x - p1.x
        jns dx_pos; Если dx < 0, x-координата отрисовки отрезка будет уменьшаться
        neg ax
        mov word ptr x_incr, 1; Если dx > 0, x-координата отрисовки отрезка будет увеличиваться
        jmp dx_neg
        
        dx_pos:
            mov word ptr x_incr, -1
        dx_neg:
            mov bx, di
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
            ; call draw_pixel
            cmp ax, bx
            jna dx_less_than_dy
            mov cx, ax
            shr cx, 1
            neg cx
            add cx, bx
        draw_line_loop1:
            cmp di, word ptr point1.x
            je exit_bres
            cmp cx, 0
            jl fractlt0
            add di, word ptr y_incr
            sub cx, ax
        fractlt0:
            add di, word ptr x_incr
            add cx, bx
            call draw_pixel
            jmp draw_line_loop1
        dx_less_than_dy:
            mov cx, bx
            shr cx, 1
            neg cx
            add cx, ax
        draw_line_loop2:
            cmp di, word ptr point1.y
            je exit_bres
            cmp cx, 0
            jl fractlt02
            add si, word ptr x_incr
            sub cx, bx
        fractlt02:
            add di, word ptr y_incr
            add cx, ax
            call draw_pixel
            jmp draw_line_loop2
        exit_bres:
    @draw_line_exit:
    pop si di cx dx bx ax
    ret
draw_line endp

; Аргументы:
;   point1: левый верхний угол прямоугольника
;   rectangle_length: длина прямоугольника
;   rectangle_height: высота прямоугольника
;   pixel_color: цвет ребер прямоугольника
; Результат:
;   Нет
; Регистры:
;   ax: промежуточные вычисления координат
draw_rectangle_hollow proc near
    push ax
    push word ptr point1.x
    push word ptr point1.y
    push word ptr point2.x
    push word ptr point2.y
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
    pop point2.y
    pop point2.x
    pop point1.y
    pop point1.x
    pop ax
    ret
draw_rectangle_hollow endp

; Аргументы:
;   point1: левый верхний угол прямоугольника
;   rectangle_length: длина прямоугольника
;   rectangle_height: высота прямоугольника
;   pixel_color: цвет заливки и ребер прямоугольника
; Результат:
;   Нет
; Регистры:
;   ax: промежуточные вычисления координат
;   cx: итератор цикла отрисовки
draw_rectangle_filled proc near
    push ax cx
    push word ptr point1.x
    push word ptr point1.y
    push word ptr point2.x
    push word ptr point2.y
    mov ax, point1.x; Сдвиг x-координаты второй точки на длину прямоугольника
    add ax, rectangle_length
    mov point2.x, ax
    mov ax, point1.y; Обе точки лежат на одной y-координате
    mov point2.y, ax
    mov cx, rectangle_height; Количетсво итераций отрисовки линий равно высоте прямоугольника
    @draw_rectangle_filled:
        call draw_line_along_x
        inc point1.y; Сдвигаем y-координаты обеих точек на 1 вниз
        inc point2.y
    loop @draw_rectangle_filled

    pop point2.y
    pop point2.x
    pop point1.y
    pop point1.x
    pop cx ax
    ret
draw_rectangle_filled endp

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
    push word ptr point1.x
    push word ptr point1.y
    push word ptr point2.x
    push word ptr point2.y
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

    pop point2.y
    pop point2.x
    pop point1.y
    pop point1.x
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
    push word ptr point1.x
    push word ptr point1.y
    push word ptr point2.x
    push word ptr point2.y
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
    
    pop point2.y
    pop point2.x
    pop point1.y
    pop point1.x
    pop cx bx ax di si
    ret
draw_line_along_y endp

; Аргументы:
;   point1: точка начала отрисовки панели цветов, левый верхний угол первого цвета
;   color_panel_size: размер метки цвета в пикселях
draw_color_panel proc near
    push si cx    
    push word ptr point1.x
    push word ptr point1.y

    mov cl, 15; Итератор цикла, он же код цвета, см. https://en.wikipedia.org/wiki/BIOS_color_attributes для кодов цветов
    mov si, color_panel_size; 
    mov rectangle_height, si
    mov rectangle_length, si
    
    @color_panel_drawing_loop:
        mov pixel_color, cl
        call draw_rectangle_filled
        add point1.x, si
    loop @color_panel_drawing_loop

    pop point1.y
    pop point1.x
    pop cx si
    ret
draw_color_panel endp

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