;Notas sobre o codigo:
;R15 é o registo que guarda o handle do console (necessario para mover o cursor) 
;O cursor é escondido no inicio do programa, e ja coloca o handle do console em R15, que fica lá o resto do programa


includelib ucrt.lib
includelib legacy_stdio_definitions.lib
includelib msvcrt.lib
extern printf:proc
extern _kbhit:proc
extern _getch:proc
extern putchar:proc
extern system:proc
extern SetConsoleCursorInfo:proc
extern SetConsoleCursorPosition:proc
extern SetConsoleTitleA:proc
extern ReadConsoleOutputCharacterA:proc
extern Sleep:proc
extern GetStdHandle:proc
extern srand:proc
extern rand:proc
extern time:proc
extern ExitProcess:proc

.data

console_title db "Snake Game - Micros P1", 0  ;Titulo da consola
FullLine db "################################################################################", 0Dh,0Ah,0
InteriorLine db "#                                                                              #",0Dh, 0Ah, 0
minX dw 0
maxX dw 79
minY dw 0
maxY dw 24

snakeX dw 200 dup(?) ;Array para guardar as posicoes X da cobra
snakeY dw 200 dup(?) ;Array para guardar as posicoes Y da cobra
posfoodX dw 0		 ;Posicao X da comida (inicializada a 0 mas depois vai receber valor random)
posfoodY dw 0	     ;Posicao Y da comida (inicializada a 0 mas depois vai receber valor random)
headX dw 40			 ;cabeça X inicial
headY dw 12			 ;cabeça Y inicial

last_fruit_steps dq 0
death_message db 0

body_collision db 0	 ;variavel para verificar se houve colisao com o corpo (0 = nao, 1 = sim)

snake_dim dq 1			;Dimensao inicial da cobra
old_snake_dim dq 1		;Dimensao anterior da cobra (usada para calcular a velocidade)
snake_direction dq 3	;Direcao inicial da cobra (0 = cima, 1 = baixo, 2 = esquerda, 3 = direita)

score_counter dq 0		;Contador de pontos
speed dq 100			;Define o tempo de espera entre cada passo 

LineCounter db 0		;Contador de linhas para imprimir a grelha
FruitCounter db 0		;variavel para verificar se a fruta foi comida (0 = comida, 1 = nao comida)

clear_screen db "cls", 0	;Comando para limpar o ecra no Windows

cursor_info dd 20, 0	;TEM Q SER DWORD PQ A FUNCAO ESPERA 8 BYTES (2 DWORDS), 0 = CURSOR INVISIVEL, 20 = TAMANHO DO CURSOR

menu_snake db 0Dh,0Ah,0Dh,0Ah,0Dh,0Ah ;Linhas em branco
     db "                      _____ _   _          _  _ ______ ", 0Dh,0Ah
     db "                     / ____| \ | |   /\   | |/ /  ____|", 0Dh, 0Ah
     db "                    | (___ |  \| |  /  \  | ' /| |__  ", 0Dh, 0Ah
     db "                     \___ \| . ` | / /\ \ |  < |  __|  ", 0Dh, 0Ah
     db "                     ____) | |\  |/ ____ \| . \| |____ ", 0Dh, 0Ah
     db "                    |_____/|_| \_/_/    \_\_|\_\______|", 0Dh, 0Ah, 0Dh, 0Ah 

     db "                By: Daniel Ramalho 70837, Goncalo Silva 70796", 0Dh, 0Ah
     db "                             e Lisandro Sequeira 71461", 0Dh,0Ah,0Dh,0Ah,0Dh,0Ah 

     db "                                1. START GAME", 0Dh,0Ah
     db "                                   2. EXIT", 0Dh,0Ah,0Dh,0Ah

	 db 0Dh,0Ah
     db "                                   CONTROLS:", 0Dh,0Ah
     db "                                    W - Up", 0Dh,0Ah
     db "                                    A - Left", 0Dh,0Ah
     db "                                    S - Down", 0Dh,0Ah
     db "                                    D - Right", 0Dh,0Ah,0

menu_game_over db 0Dh,0Ah,0Dh,0Ah,0Dh,0Ah ;Linhas em branco
	 db"	     _____                         ____                 ", 0Dh,0Ah
	 db"	    / ____|                       / __ \                ", 0Dh,0Ah
	 db"	   | |  __  __ _ _ __ ___   ___  | |  | |_   _____ _ __ ", 0Dh,0Ah
	 db"	   | | |_ |/ _` | '_ ` _ \ / _ \ | |  | \ \ / / _ \ '__|", 0Dh,0Ah
	 db"	   | |__| | (_| | | | | | |  __/ | |__| |\ V /  __/ |   ", 0Dh,0Ah
	 db"	    \_____|\__,_|_| |_| |_|\___|  \____/  \_/ \___|_|   ", 0Dh,0Ah,0Dh,0Ah
	 db"	                Game Over! Your Score is: %d", 0Dh,0Ah,0Dh,0Ah
	 db"                        %s"
	 db 0Dh,0Ah,0Dh,0Ah
	 db "                               1. TRY AGAIN", 0Dh,0Ah
     db "                                  2. EXIT", 0Dh,0Ah,0Dh,0Ah, 0

wall_death db "The snake hit a wall, oops!", 0
body_death db "The snake tried to eat itself!", 0
hunger_death db "The snake died of hunger...", 0Dh,0Ah
			 db "                         how could you do that :(", 0
win_death db "The snake is full, you win!", 0

.code

HideCursor proc
	;Funcao de esconder o cursor e mudar o titulo da consola

	lea rcx, console_title	;carrega o endereço do título da consola em rcx (primeiro argumento da função SetConsoleTitleA)
	sub rsp, 40				;reserva espaço na stack (shadow)
	call SetConsoleTitleA	;chama a função externa SetConsoleTitleA para definir o título da consola
	add rsp, 40				;restaura a stack

	mov rcx, -11				;coloca -11 em rcx, que é o valor para obter o handle do console de output (monitor)
    sub rsp, 40					;reserva espaço na stack (shadow)
	call GetStdHandle			;chama a funcao externa para obter o handle do console (fica em rax)
	add rsp, 40					;restaura a stack
	mov r15, rax				;move o handle do console para r15 (para usar mais tarde)
	mov rcx, r15				;coloca o handle do console em rcx (primeiro argumento da funcao SetConsoleCursorInfo)
	lea rdx, cursor_info		;coloca o endereço da estrutura cursor_info em rdx (segundo argumento da funcao SetConsoleCursorInfo)
	sub rsp, 40					;reserva espaço na stack (shadow)
	call SetConsoleCursorInfo	;chama a funcao externa para esconder o cursor
	add rsp, 40					;restaura a stack
	ret
HideCursor endp

menu proc
	
	cmp r13, 1
	je start_game

	xor r13, r13
	xor rcx, rcx	;zera rcx
    sub rsp, 40		;reserva espaço na stack (shadow)
    call time       ;coloca o tempo atual em rax
    add rsp, 40		;restaura a stack
    mov rcx, rax	;move o tempo atual para rcx (primeiro argumento da função srand)
    sub rsp, 40		;reserva espaço na stack (shadow)
    call srand      ;gera a seed para os numeros random a partir do tempo atual
    add rsp, 40		;restaura a stack

	lea rcx, menu_snake		;carrega o endereço do menu em rcx (primeiro argumento da função printf)
	sub rsp, 32				;reserva espaço na stack (shadow)
	call printf				;chama a função externa printf para imprimir o menu
	add rsp, 32				;restaura a stack

	wait_key:
		call _kbhit			;Espera por uma tecla
		test eax, eax		;Se nao foi pressionada nenhuma tecla, rax = 0, logo test (and) dá 0
		jz wait_key			;verifica se o AND anterior deu 0, se sim volta a esperar por uma tecla
		sub rsp, 32			;reserva espaço na stack (shadow)
		call _getch			;chama funcao externa para ler a tecla pressionada
		add rsp, 32			;restaura a stack

		cmp eax, '1'		;compara a tecla pressionada com '1'
		je start_game       ; começa o jogo, se a tecla for '1'

		cmp eax, '2'		;compara a tecla pressionada com '2'
		je exit_game		;termina o programa, se a tecla for '2'

		jmp wait_key        ;ignora teclas inválidas, volta a esperar por uma tecla

	start_game:
		lea rcx, clear_screen	;carrega o endereço do comando para limpar o ecra em rcx (primeiro argumento da função system)
		sub rsp, 32				;reserva espaço na stack (shadow)
		call system				;chama a função externa system para limpar o ecra
		add rsp, 32				;restaura a stack

		sub rsp, 40		;reserva espaço na stack (shadow)
		call rand		;chama a funcao externa rand para gerar um numero aleatorio
		add rsp, 40		;restaura a stack

		xor rdx, rdx				;zera rdx -> necessário para a divisão (div usa RDX:RAX)
		mov rcx, 4					;divisor = 4 -> qualquer numero dividido por 4 dá resto entre 0 e 3   
		div rcx						;divide rax por 4, quociente em rax, resto em rdx     
		mov rax, rdx				;movemos o resto para rax (0..3)
		mov snake_direction, rax	;coloca o valor de rax(o numero que indica a direcao) em snake_direction

		call print_grelha		;chama a função para imprimir a grelha do jogo
		call print_head         ;chama a função para imprimir a cabeça da cobra
		call spawn_fruit		;chama a função para spawnar a fruta
		call game_loop			;chama a função do ciclo principal do jogo
		jmp final				;vai mostrar o ecrã de game over quando o jogo acabar

	final:
		call game_over		;chama a função para mostrar o ecrã de game over
		ret

	exit_game:
		xor rax, rax		;zera rax
		xor rcx, rcx		;zera rcx (primeiro argumento da funcao ExitProcess - codigo de saida 0)
		sub rsp, 32			;reserva espaço na stack (shadow)
		call ExitProcess	;chama a funcao externa para terminar o programa
		add rsp, 32			;restaura a stack
		ret
menu endp

print_grelha proc
	Grelha: 
		cmp LineCounter, 0		;compara LineCounter com 0 (no inicio, linecounter esta a 0, ent vai ser igual)
		je FullLinePrint		;se for igual, imprime a linha cheia
		cmp LineCounter, 24		;compara LineCounter com 24 (ultima linha da grelha)
		je FullLinePrint		;se for igual, imprime a linha cheia
		cmp LineCounter, 24		;compara LineCounter com 24 (ultima linha da grelha)
		jg EndGrelha			;se for maior, termina a grelha (depois de imprimir a ultima linha, linecounter fica a 25, ent vai saltar)
		jmp InteriorLinePrint	;se nao for nenhuma das anteriores, imprime a linha interior

	FullLinePrint: 
		lea rcx, FullLine		;carrega o endereço da FullLine em rcx (primeiro argumento da função printf)
		sub rsp, 40				;reserva espaço na stack (shadow)
		call printf				;chama a função externa printf para imprimir a linha cheia
		add rsp, 40				;restaura a stack
		inc LineCounter			;incrementa LineCounter
		jmp Grelha				;salto incondicional para o inicio do ciclo da grelha

	InteriorLinePrint:
		lea rcx, InteriorLine	;carrega o endereço da InteriorLine em rcx (primeiro argumento da função printf)
		sub rsp, 40				;reserva espaço na stack (shadow)
		call printf				;chama a função externa printf para imprimir a linha interior
		add rsp, 40				;restaura a stack
		inc LineCounter			;incrementa LineCounter
		jmp Grelha				;salto incondicional para o inicio do ciclo da grelha

	EndGrelha:
	    ret		
	
	print_grelha endp

	print_head proc

		mov rcx, r15			;coloca o handle do console (em r15) em rcx (primeiro argumento da funcao SetConsoleCursorPosition)
		xor rdx, rdx			;zera rdx (segundo argumento da funcao SetConsoleCursorPosition)
		mov dx, 12				;coloca 12 em dx (posição vertical do cursor)
		shl rdx, 16				;desloca rdx 16 bits para a esquerda (prepara o valor para a funcao SetConsoleCursorPosition)
		mov dx, 40				;coloca 40 em dx (posição horizontal do cursor)
		
		sub rsp, 40						;reserva espaço na stack (shadow)
		call SetConsoleCursorPosition	;chama a funcao externa para mover o cursor para a posicao (40,12)
		add rsp, 40						;restaura a stack
	    mov rcx, '@'					;coloca o caractere '@' em rcx (primeiro argumento da funcao putchar)
		
		sub rsp, 40			;reserva espaço na stack (shadow)
		call putchar		;chama a funcao externa para imprimir o caractere '@' na posicao (40,12)
		add rsp, 40			;restaura a stack
		ret
	print_head endp
			
game_loop proc
		mov ax, headX			;carrega a posicao X da cabeca em rax
		mov snakeX[0], ax		;guarda a posicao X da cabeca no array snakeX na posicao 0
		mov ax, headY			;carrega a posicao Y da cabeca em rax
		mov snakeY[0], ax		;guarda a posicao Y da cabeca no array snakeY na posicao 0
		mov snakeX[2], 0        ;coloca a segunda posiçao do corpo a 0 (terminador)
		mov snakeY[2], 0        ;coloca a segunda posiçao do corpo a 0 (terminador)

	game_loop_start:
		inc last_fruit_steps
		sub rsp, 40		;reserva espaço na stack (shadow)
		call _kbhit		;Espera por uma tecla
		add rsp, 40		;restaura a stack
		test eax, eax	;Se nao foi pressionada nenhuma tecla, rax = 0, logo test (and) dá 0
		jz auto_move    ;nenhuma tecla -> mover automaticamente na mesma direcao

		sub rsp, 40		;reserva espaço na stack
		call _getch		;chama a funcao externa getchar (isto é executado caso uma tecla seja pressionada)
		add rsp, 40		;restaura a stack

		cmp eax, 'd'	;compara a tecla pressionada com 'd'
		je set_right	;se for igual, define a direcao para a direita
		cmp eax, 'a'	;compara a tecla pressionada com 'a'
		je set_left		;se for igual, define a direcao para a esquerda
		cmp eax, 'w'	;compara a tecla pressionada com 'w'
		je set_up		;se for igual, define a direcao para cima
		cmp eax, 's'	;compara a tecla pressionada com 's'
		je set_down		;se for igual, define a direcao para baixo
		jmp auto_move	;tecla invalida -> mover automaticamente na mesma direcao

	set_up:
		mov snake_direction, 0		;0 = cima
		jmp auto_move				;salta para mover automaticamente

	set_down:
		mov snake_direction, 1		;1 = baixo
		jmp auto_move				;salta para mover automaticamente

	set_left:
		mov snake_direction, 2		;2 = esquerda
		jmp auto_move				;salta para mover automaticamente

	set_right:
		mov snake_direction, 3		;3 = direita
		jmp auto_move				;salta para mover automaticamente

	auto_move:
		mov rcx, r15	;coloca o handle do console (em r15) em rcx (primeiro argumento da funcao SetConsoleCursorPosition)
		xor rdx, rdx	;zera rdx para preparar o segundo argumento de SetConsoleCursorPosition
        
        cmp snake_dim, 1	;compara a dimensao da cobra com 1 (so a cabeça)  
        je erase_head		;se for igual, apagar so a cabeca (sem corpo)
        
        mov r11, snake_dim
        dec r11                 ; r11 = Dimensão - 1
		mov dx, snakeY[r11*2]	
		shl rdx, 16				
		mov dx, snakeX[r11*2]	
        jmp set_cursor_erase
        
    erase_head:
		mov dx, headY	;carrega a posicao Y da cabeca em dx
		shl rdx, 16		;desloca rdx 16 bits para a esquerda
		mov dx, headX	;carrega a posicao X da cabeca em dx

    set_cursor_erase:
		sub rsp, 40						;reserva espaço na stack (shadow)
		call SetConsoleCursorPosition	;move o cursor para a posicao da cauda (se a dimensao for 1, é a cabeca)
		add rsp, 40						;restaura a stack
        
		mov rcx, ' '		;coloca o caractere ' ' (espaco) em rcx (primeiro argumento da funcao putchar)	
		sub rsp, 40			;reserva espaço na stack (shadow)	
		call putchar		;chama a funcao externa para imprimir o caractere ' ' (apagar a cauda ou cabeca)
		add rsp, 40			;restaura a stack

	move_body:
        ;Aqui move-se o corpo da cobra nos arrays snakeX e snakeY colocando a posiçao i-1 na posiçao i

		push rsi			;salva rsi na stack	               
		mov rsi, snake_dim	;carrega a dimensao da cobra em rsi	
	
	shift_loop:
        cmp rsi, 0			    ;Verifica se rsi é 0 (chegou ao elemento 1)
		je end_shift_loop		;Se for 0, sai do loop
		
		mov ax, snakeX[2*rsi-2]	;carrega em ax o que está na posiçao i-1 do array snakeX
		mov snakeX[2*rsi], ax	;coloca o que está em ax na posiçao i do array snakeX
		
		mov ax, snakeY[2*rsi-2] ;carrega em ax o que está na posiçao i-1 do array snakeY
		mov snakeY[2*rsi], ax	;coloca o que está em ax na posiçao i do array snakeY
		
		dec rsi					;decrementa rsi (o contador)
		jmp shift_loop			;repete o ciclo, para atualizar os vetores completamente

	end_shift_loop:               
		pop rsi					;restaura rsi da stack
        
		cmp snake_direction, 0	;compara snake_direction com 0				
		je move_up				;se for 0, mover para cima
		cmp snake_direction, 1	;compara snake_direction com 1
		je move_down			;se for 1, mover para baixo
		cmp snake_direction, 2	;compara snake_direction com 2
		je move_left			;se for 2, mover para esquerda
		cmp snake_direction, 3	;compara snake_direction com 3
		je move_right			;se for 3, mover para direita

	move_up:
		dec headY				;decrementa a posicao Y da cabeca (mover para cima)
		cmp headY, 0			;compara a posicao Y da cabeca com o limite minimo (minY)
		mov death_message, 0	;0 morreu por parede
		je ending				;se for igual, termina o jogo (a cabeca bateu na parede)
		cmp headY, 24			;compara a posicao Y da cabeca com o limite maximo (maxY)
		mov death_message, 0	;0 morreu por parede
		je ending				;se for igual, termina o jogo (a cabeca bateu na parede)
		jmp fruit
		
	move_down:
		inc headY				;incrementa a posicao Y da cabeca (mover para baixo)
		cmp headY, 0			;compara a posicao Y da cabeca com o limite minimo (minY)
		mov death_message, 0	;0 morreu por parede
		je ending				;se for igual, termina o jogo (a cabeca bateu na parede)
		cmp headY, 24			;compara a posicao Y da cabeca com o limite maximo (maxY)
		mov death_message, 0	;0 morreu por parede
		je ending				;se for igual, termina o jogo (a cabeca bateu na parede)
		jmp fruit

	move_left:
		dec headX				;decrementa a posicao X da cabeca (mover para esquerda)
		cmp headX, 0			;compara a posicao X da cabeca com o limite minimo (minX)
		mov death_message, 0	;0 morreu por parede
		je ending				;se for igual, termina o jogo (a cabeca bateu na parede)
		cmp headX, 79			;compara a posicao X da cabeca com o limite maximo (maxX)
		mov death_message, 0	;0 morreu por parede
		je ending				;se for igual, termina o jogo (a cabeca bateu na parede)
		jmp fruit

	move_right:
		inc headX				;incrementa a posicao X da cabeca (mover para direita)
		cmp headX, 0			;compara a posicao X da cabeca com o limite minimo (minX)
		mov death_message, 0	;0 morreu por parede
		je ending				;se for igual, termina o jogo (a cabeca bateu na parede)
		cmp headX, 79			;compara a posicao X da cabeca com o limite maximo (maxX)
		mov death_message, 0	;0 morreu por parede
		je ending				;se for igual, termina o jogo (a cabeca bateu na parede)
		jmp fruit

fruit:	
		;quando se faz shift dos vetores, a posiçao 1 fica com o que tinha na posiçao 0 (cabeça)
		;no entanto, a posiçao 0, continua com esse mesmo valor
		;aqui atualizamos a posiçao 0 com a nova posiçao da cabeça

		push rbx			;salva rbx na stack
		push rdx			;salva rdx na stack
		mov bx, headX		;carrega headX em bx
		mov dx, headY		;carrega headY em dx
		mov snakeX[0], bx	;coloca a posicao X da cabeca em snakeX[0]
		mov snakeY[0], dx	;coloca a posicao Y da cabeca em snakeY[0]
		pop rdx				;restaura rdx da stack
		pop rbx				;restaura rbx da stack

		call collison_check		;chama a funcao para verificar colisao com o corpo
		cmp body_collision, 1	;verifica se houve colisao com o corpo
		je ending				;se houve colisao, termina o jogo
        
		call snake_eat_fruit	;nao havendo colisao, chama a funcao para verificar se comeu a fruta
		cmp FruitCounter, 1		;1 = fruta nao comida, 0 = fruta comida
		je verify_score			;se fruta nao comida, salta para not_eaten
		call spawn_fruit		;se fruta comida, chama a funcao para spawnar nova fruta


verify_score:
		mov rax, snake_dim
		mov rbx, 10
		mul rbx              ; ax = snake_dim * 10
		add rax, 150         ; ax = MAX_STEPS
		cmp last_fruit_steps, rax
		mov death_message, 2 ;2 é a mensagem de morte por fome
		jg ending          ; morreu por fome

	not_eaten:

		cmp snake_dim, 2	;compara a dimensao da cobra com 2
        jl draw_head        ;se dim = 1, so tem cabeca, ent salta o desenho do corpo   
        
        mov rcx, r15	    ;coloca o handle do console (em r15) em rcx (primeiro argumento da funcao SetConsoleCursorPosition)
		xor rdx, rdx		;zera rdx
		mov dx, snakeY[2]	;coloca o Y do primeiro segmento do corpo em dx  (antiga cabeca) 
		shl rdx, 16			;desloca rdx 16 bits para a esquerda
		mov dx, snakeX[2]	;coloca o X do primeiro segmento do corpo em dx (antiga cabeca)
        
		sub rsp, 40						;reserva espaço na stack (shadow)
		call SetConsoleCursorPosition	;Move cursor para a posiçao do corpo
		add rsp, 40						;restaura a stack
        
		mov rcx, '+'			;Coloca o caractere '+' para o corpo
		sub rsp, 40				;reserva espaço na stack (shadow)
		call putchar			;Desenha o corpo no lugar onde estava a cabeca
		add rsp, 40				;restaura a stack
        
draw_head:				;agora vai desenhar a cabeca na sua nova posiçao

		mov rcx, r15	;coloca o handle do console (em r15) em rcx (primeiro argumento da funcao SetConsoleCursorPosition)
		xor rdx, rdx	;zera rdx
		mov dx, headY	;coloca a posicao Y da cabeça em dx
		shl rdx, 16		;desloca rdx 16 bits para a esquerda
		mov dx, headX	;coloca a posicao X da cabeça em dx
		sub rsp, 40		;reserva espaço na stack (shadow)				
		call SetConsoleCursorPosition	;Move cursor para a nova posição da cabeça
		add rsp, 40		;restaura a stack
		mov rcx, '@'	;coloca o caractere '@' para a cabeça			
		sub rsp, 40		;reserva espaço na stack (shadow)	
		call putchar    ;Desenha a cabeça
		add rsp, 40		;restaura a stack

	sleep_step:					;pausa entre passos do jogo
		mov r11, score_counter	;carrega o valor do score_counter em r11
		mov r12, snake_dim		;carrega o valor da snake_dim em r12
		add r11, r12			;score = score + snake_dim
		mov score_counter, r11	;atualiza o score_counter com o novo valor
		xor r11, r11			;zera r11

		mov rcx, speed      ;velocidade (tempo de espera em milisegundos)
		sub rsp, 40		    ;reserva espaço na stack (shadow)
		call Sleep		    ;pausa entre passos
		add rsp, 40		    ;restaura a stack
		jmp game_loop_start ;repete o ciclo do jogo

	ending:
		ret
game_loop endp

spawn_fruit proc
rand_value:
    ;gerar X
    sub rsp, 40		;reserva espaço na stack
    call rand		;chama rand e o valor fica em rax          
    add rsp, 40		;restaura a stack

    xor rdx, rdx         ;zera rdx -> necessário para a divisão (div usa RDX:RAX)
    mov rcx, 78          ;divisor = 78 -> qualquer numero dividido por 78 dá resto entre 0 e 77
    div rcx              ;divide rax por 78, quociente em rax, resto em rdx
    mov rax, rdx         ;movemos o resto para rax (0..77)
    inc rax              ;agora 1..78 (evitar a parede na coluna 0) 

    mov bx, headX		;carrega a posicao X da cabeca em bx
    cmp ax, bx			;compara a posicao X da fruta com a posicao X da cabeca
    je rand_value       ; se coincide com a cabeça, gera nova posição X

    mov posfoodX, ax	; guarda pos X 

    ;gerar Y
    sub rsp, 40		;reserva espaço na stack
    call rand		;chama rand e o valor fica em rax
    add rsp, 40		;restaura a stack

    xor rdx, rdx    ;zera rdx -> necessário para a divisão (div usa RDX:RAX)
    mov rcx, 23     ;divisor = 23 -> qualquer numero dividido por 23 dá resto entre 0 e 22   
    div rcx         ;divide rax por 23, quociente em rax, resto em rdx     
    mov rax, rdx	;movemos o resto para rax (0..22)
    inc rax			;agora 1..23 (evitar a parede na linha 0)   
    mov posfoodY, ax	;guarda pos Y

	call check_fruit_body_collision
	cmp rax, 1
	je rand_value

    inc FruitCounter	;marca fruta gerada

print_fruit:
    mov rcx, r15					;coloca o handle do console (em r15) em rcx (primeiro argumento da funcao SetConsoleCursorPosition)
    xor rdx, rdx					;zera rdx
    mov dx, posfoodY				;coloca a posicao Y da fruta em dx
    shl rdx, 16						;desloca rdx 16 bits para a esquerda (prepara o valor para a funcao SetConsoleCursorPosition)
    mov dx, posfoodX				;coloca a posicao X da fruta em dx     
    sub rsp, 40						;reserva espaço na stack (shadow)
    call SetConsoleCursorPosition	;chama a funcao externa para mover o cursor para a posicao (posfoodX, posfoodY)
    add rsp, 40						;restaura a stack

    mov ecx, '*'	;coloca o caractere '*' em rcx (primeiro argumento da funcao putchar)
    sub rsp, 40		;reserva espaço na stack (shadow)
    call putchar	;chama a funcao externa para imprimir o caractere '*' na posicao (posfoodX, posfoodY)
    add rsp, 40		;restaura a stack

    ret
spawn_fruit endp


snake_eat_fruit proc
verify_posX:
    mov ax, headX				;carrega a posicao X da cabeca em ax
    mov bx, posfoodX			;carrega a posicao X da fruta em bx
    cmp ax, bx					;compara ax com bx
    jne end_snake_eat_fruit		;se nao forem iguais, salta para o fim da funcao
    jmp verify_posY				;se forem iguais, verifica a posicao Y

verify_posY:
    mov ax, headY				;carrega a posicao Y da cabeca em ax
    mov bx, posfoodY			;carrega a posicao Y da fruta em bx
    cmp ax, bx					;compara ax com bx
    jne end_snake_eat_fruit		;se nao forem iguais, salta para o fim da funcao (se for igual, comeu a fruta, logo snake_dim vai aumentar)

    mov r11, snake_dim			;carrega o valor da snake_dim em r11
    mov old_snake_dim, r11		;guarda o valor antigo da snake_dim

    inc snake_dim				;incrementa a snake_dim (a cobra cresceu)
    mov FruitCounter, 0			;marca que a fruta foi comida
	mov last_fruit_steps, 0
	cmp snake_dim, 200			;compara a snake_dim com 200 (tamanho maximo da cobra)
	mov death_message, 3
	je over

    mov rax, snake_dim			;carrega o valor da snake_dim em rax
    mov rbx, old_snake_dim		;carrega o valor antigo da snake_dim em rbx
    cmp rax, rbx				;compara os dois valores
    jle end_snake_eat_fruit		;se o valor atual for menor ou igual ao antigo, salta para o fim da funcao

    mov rdx, 0					;zera rdx (necessário para a divisão - div usa RDX:RAX)
    mov rcx, 10					;divisor = 10
    div rcx						;divide rax por 10, quociente em rax, resto em rdx
    cmp rdx, 0					;compara o resto com 0
    jne end_snake_eat_fruit		;se nao for igual a 0, salta para o fim da funcao

    mov rcx, speed				;carrega o valor da speed em rcx
    sub rcx, 5					;decrementa 5 milisegundos (aumenta a velocidade da cobra)
    mov speed, rcx				;atualiza o valor da speed

end_snake_eat_fruit:
    ret

over: 
	call game_over				;chama a funcao de game over
	xor rax, rax				;zera rax
	xor rcx, rcx				;zera rcx (primeiro argumento da funcao ExitProcess - codigo de saida 0)
	sub rsp, 40					;reserva espaço na stack (shadow)
	call ExitProcess			;chama a funcao externa para terminar o programa
	add rsp, 40					;restaura a stack
	ret
snake_eat_fruit endp


game_over proc
	lea rcx, clear_screen		;carrega o endereço do comando para limpar o ecra em rcx (primeiro argumento da função system)
	sub rsp, 40					;reserva espaço na stack (shadow)
	call system					;chama a função externa system para limpar o ecra
	add rsp, 40					;restaura a stack
    lea rcx, menu_game_over		;carrega o endereço do menu de game over em rcx (primeiro argumento da função printf)
	mov rdx, score_counter		;coloca o valor do score em rdx (segundo argumento da função printf)

	cmp death_message, 0
	lea r8, wall_death
	je print
	cmp death_message, 1
	lea r8, body_death
	je print
	cmp death_message, 2
	lea r8, hunger_death
	je print
	cmp death_message, 3
	lea r8, win_death

print:
	sub rsp, 40					;reserva espaço na stack (shadow)
	call printf					;chama a função externa printf para imprimir o menu de game over
	add rsp, 40					;restaura a stack

wait_restart:
	sub rsp, 40		;reserva espaço na stack (shadow)
	call _kbhit		;Espera por uma tecla
	add rsp, 40		;restaura a stack
	test eax, eax	;Se nao foi pressionada nenhuma tecla, rax = 0, logo test (and) dá 0
	jz wait_restart
	sub rsp, 40		;reserva espaço na stack
	call _getch		;chama a funcao externa getchar (isto é executado caso uma tecla seja pressionada)
	add rsp, 40		;restaura a stack
	
	cmp eax, '1'		;compara a tecla pressionada com '1'
	je restart_game       ; começa o jogo, se a tecla for '1'

	cmp eax, '2'		;compara a tecla pressionada com '2'
	je end_of_game		;termina o programa, se a tecla for '2'

	jmp wait_restart        ;ignora teclas inválidas, volta a esperar por uma tecla

restart_game:
	lea rcx, clear_screen
	sub rsp, 40
	call system
	add rsp, 40
	call Init_game
	call menu

end_of_game:
	ret
game_over endp


Init_game proc

	mov posfoodX, 0		 ;Posicao X da comida (inicializada a 0 mas depois vai receber valor random)
	mov posfoodY, 0	     ;Posicao Y da comida (inicializada a 0 mas depois vai receber valor random)
	mov headX, 40			 ;cabeça X inicial
	mov headY, 12			 ;cabeça Y inicial

	mov last_fruit_steps, 0

	mov body_collision, 0	 ;variavel para verificar se houve colisao com o corpo (0 = nao, 1 = sim)

	mov snake_dim, 1			;Dimensao inicial da cobra
	mov old_snake_dim, 1		;Dimensao anterior da cobra (usada para calcular a velocidade)
	mov snake_direction, 3	;Direcao inicial da cobra (0 = cima, 1 = baixo, 2 = esquerda, 3 = direita)

	mov score_counter, 0		;Contador de pontos
	mov speed, 100			;Define o tempo de espera entre cada passo 

	mov LineCounter, 0		;Contador de linhas para imprimir a grelha
	mov FruitCounter, 0		;variavel para verificar se a fruta foi comida (0 = comida, 1 = nao comida)

	mov r13, 1

Init_game endp


collison_check proc			;funcao para verificar se a cabeca colidiu com o proprio corpo
	
	push rsi				;salva rsi na stack
	push rbx				;salva rbx na stack
	push rdx				;salva rdx na stack
	mov body_collision, 0	;zera body_collision (sem colisao inicialmente)
	
	cmp snake_dim, 2		;compara a dimensao da cobra com 2
	jl end_cmp_loop			;se for menor, nao ha colisao possivel, salta para o fim
	
	mov rsi, 0				;inicializa o contador rsi a 0
	mov bx, snakeX[0]		;carrega a posicao X da cabeca em bx (ja é a proxima posicao)
	mov dx, snakeY[0]		;carrega a posicao Y da cabeca em dx (ja é a proxima posicao)

cmp_loop:
	cmp rsi, snake_dim		;Compara o contador com a dimensao da cobra
	je end_cmp_loop			;Se forem iguais, sai do loop
	
	cmp bx, snakeX[rsi*2+2]	;compara a proxima posicao X da cabeça com as posicoes X do corpo
	jne next_segment		;se nao forem iguais em X
							;significa que nao ha colisao pq precisa de ter X e Y iguais 
							;para ter colisao, entao salta para a proxima iteracao se nao for igual
	
	cmp dx, snakeY[rsi*2+2]	;compara a proxima posicao Y da cabeça com as posicoes Y do corpo
	jne next_segment		;se nao forem iguais em Y, salta para a proxima iteracao
	
	;Esta parte é executada se houver colisao (X e Y da cabeca iguais a um X e Y do corpo)
	mov body_collision, 1	;marca colisao
	jmp end_cmp_loop		;salta para o fim do loop
	
next_segment:
	inc rsi					;incrementa o contador
	jmp cmp_loop			;repete o ciclo
	
end_cmp_loop:
	mov death_message, 1	;1 morreu por proprio corpo
	pop rdx					;restaura rdx da stack
	pop rbx					;restaura rbx da stack
	pop rsi					;restaura rsi da stack
	ret

collison_check endp

check_fruit_body_collision proc	;funcao para verificar se a fruta spawnou em cima do corpo da cobra
	
	push rsi				;salva rsi na stack
	push rbx				;salva rbx na stack
	push rdx				;salva rdx na stack

	xor rax, rax			;zera rax (vai servir para indicar se houve colisao)
	mov rsi, 0				;inicializa o contador rsi a 0
	mov bx, posfoodX		;carrega a posicao X da fruta em bx
	mov dx, posfoodY		;carrega a posicao Y da fruta em dx
check_loop:
	cmp rsi, snake_dim		;Compara o contador com a dimensao da cobra
	je end_check_loop		;Se forem iguais, sai do loop

	cmp bx, snakeX[rsi*2]	;compara a posicao X da fruta com as posicoes X do corpo
	jne next_check_segment	;se nao forem iguais em X
							;significa que nao ha colisao pq precisa de ter X e Y iguais 
							;para ter colisao, entao salta para a proxima iteracao se nao for igual
	cmp dx, snakeY[rsi*2]	;compara a posicao Y da fruta com as posicoes Y do corpo
	jne next_check_segment	;se nao forem iguais em Y, salta para a proxima iteracao

	;Esta parte é executada se houver colisao (X e Y da fruta iguais a um X e Y do corpo)
	mov rax, 1			;coloca 1 em rax (1 = houve colisao)
	jmp end_check_loop	;sai do loop

next_check_segment:
	inc rsi				;incrementa o contador para a proxima iteraçao
	jmp check_loop		;salta para o inicio do loop

end_check_loop:
	pop rdx				;restaura rdx da stack
	pop rbx				;restaura rbx da stack
	pop rsi				;restaura rsi da stack
	ret

check_fruit_body_collision endp

main proc
	call HideCursor 	;esconde o cursor e guarda o handle do console em r15
	call menu			;mostra o menu inicial e inicia o jogo
	xor rax, rax		;retorna 0
	ret
main endp

end