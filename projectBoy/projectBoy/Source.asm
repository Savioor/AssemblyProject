include /masm32/include/masm32rt.inc

include drd.inc
includelib drd.lib

.686

.data

; ----------------- equ declaration ----------------

;#region

; game stages enum
Stage_MENU equ 0 ; The playe is in the menu, show and handle the menu
Stage_PLAYING equ 1 ; The player is playing, handle the game
Stage_GAMEOVER equ 2 ; The player has lost, show game over screen
Stage_WIN equ 3 ; The player has won, show win screen
Stage_EXIT equ 4 ; The player is quiting the game

; Boolean shortcut
FALSE equ 0
TRUE equ 1

ofst equ offset ; I'm lazy

playerSpeed equ 8 ; The speed of the player

; Different gameObject declarations
gameObjectSize equ 56 ; the size of the struct
go_y equ 0 ; Offsets of different elements it the struct
go_x equ 4
go_sprite equ 8
go_htbxX equ 12
go_htbxY equ 16
go_xV equ 20
go_yV equ 24
go_ai equ 28
go_exists equ 32
go_xFrq equ 36
go_yFrq equ 40
go_coll equ 44
go_points equ 48
go_collFunc equ 52

imageObjectSize equ 20 ; The size of the Img<> struct

; Enemy sizes (hitbox)
enemy_width equ 20
enemy_height equ 30

; starting point for brick initilization (more explanation in the brick section)
baseBrickX equ 168
baseBrickY equ 450

; For the image declaration
numbersOfst equ 16

;#endregion

; ---------------- Object defenition ----------------

;#region

; Every thing that's visible on screen except UI elements is a gameobject
GameObject STRUCT
	y DWORD ? ; y position
	x DWORD ? ; x position
	sprite DWORD ? ; image pointer
	hitBoxXOffset DWORD ? ; how far right does the hitbox strech
	hitBoxYOffset DWORD ? ;  how far down does the hitbox strech
	xVelocity DWORD 0 ; How far does the x position move in a tick
	yVelocity DWORD 0 ; How far does the y position move in a tick
	ai DWORD 0 ; pointer to the function which controlls this object
	exists DWORD FALSE ; does this exist (To decide if you need to display it, check collision, run ai and move it)
	XFreq DWORD 1 ; once in how many frames does the object move once x
	yFreq DWORD 1 ; same but y
	checkCollision DWORD FALSE ; Is this a bullet (basiclly)
	pointsOnKill DWORD 0 ; How many points do you get when this shit dies
	collisionFunc DWORD ofst defaultCollisionFunc ; What happenes when someone touches you ;)
GameObject ENDS

;#endregion

; ----------- Image location declaration -----------

;#region

d_Player_Still BYTE "Sprites/Player/Player_Regular.bmp", 0
d_Player_Bullet BYTE "Sprites/Player/Player_Bullet.bmp", 0
d_Enemy0 BYTE "Sprites/Enemies/Enemy0.bmp", 0
d_EnemyBullet0 BYTE "Sprites/Enemies/Enemy_Bullet.bmp", 0
d_Brick4hp BYTE "Sprites/Shields/Brick4hp.bmp", 0
d_Brick3hp BYTE "Sprites/Shields/Brick3hp.bmp", 0
d_Brick2hp BYTE "Sprites/Shields/Brick2hp.bmp", 0
d_Brick1hp BYTE "Sprites/Shields/Brick1hp.bmp", 0
d_background BYTE "Sprites/background.bmp", 0
d_gameoverScreen BYTE "Sprites/Screens/gameOverScreen.bmp", 0
d_winScreen BYTE "Sprites/Screens/winScreen.bmp", 0
d_mainMenu BYTE "Sprites/Screens/menuScreen.bmp", 0
d_numberBase BYTE "Sprites/Numbers/0.bmp", 0
; numbersOfst equ 16

;#endregion

; ------------ Image memory decleration -------------

;#region

Player_Still Img<>
Player_Bullet Img<>
Enemy0 Img<>
EnemyBullet0 Img<>
; The next 4 lines of code are kinda equivelent to 'Brick4hp Img 4 dup (<?>)'
; Img<> size is 20 bytes
Brick4hp Img<>
Brick3hp Img<>
Brick2hp Img<>
Brick1hp Img<>
background Img<>
gameoverScreen Img<>
winScreen Img<>
mainMenu Img<>
numbersArray Img 10 dup (<?>)

;#endregion

; --------------- Object Declaration ---------------

;#region

allGameObjects GameObject 110 dup (<?>) ; in that order: 55 enemies, 15 enemy bullets, 40 bricks
playerObject GameObject<> ; The object representing the player himself
playerBullet GameObject<> ; The bullet that the player shoots

; I don't really have a good category for this but it's the windows name
windowName BYTE "Spave Invaders - by Alexey Shapovalov", 0

;#endregion

; ----------- Brick location declaration -----------

;#region

; each @ is 10x10 pixels, - are defined by surrounding @ or markings
; coordinates are adjusted from base point (marked in drawing)
;
;---------------------------------
;----------@@@@----------@@@@-----
;|---168--|@@@@|---168--|@@@@-----	etc.
;----------@--@----------@--@-----
;-----base-^----------------------

; Base brick x & y declaration at equ declaration

; Y Offest array

yOffsetFromBaseBrick DWORD 0, 0, -10, -10, -10, -10, -20, -20, -20, -20

; X offset array:

xOffsetFromBaseBrick DWORD 0, 30, 0, 10, 20, 30, 0, 10, 20, 30

;#endregion

; ---------------------- flags ---------------------

;#region

MOVE_LEFT BYTE FALSE ; Are the invaders moving left? 
LEADER_SPOKE BYTE FALSE ; Did the leader say his word?
JUMP_DOWN BYTE FALSE ; Should we go lower?
BULLET_AMOUNT BYTE 0 ; How many bullets alive now?
INVADER_SPEED BYTE 16 ; How fast should the invaders go?
SCORE BYTE 0 ; How many enemies did the player kill
GAME_STAGE BYTE Stage_MENU ; options for this flag are shown in the game stages enum defined at equ declarations
FRAME_COUNT DWORD 0 ; How many frames have passed?
LEADER DWORD ? ; The location of the leading invader in memory

;#endregion

.code

; This function generates a random 32 bit number and passes with eax
generateRandom proc
	rdseed ax
	shl eax, 4
	rdseed ax
	ret
generateRandom endp

; This function returns (firstElement % secondElement) into eax
modulu proc, firstElement:DWORD, secondElement:DWORD
	push edx

	xor edx, edx ; Clear edx for division
	mov eax, firstElement ; eax = firstElement
	div secondElement ; firstElement / secondElemeny
	mov eax, edx ; eax = firstElement % secondElemeny (because edx stores the remainder of the division)

	pop edx
	ret 8
modulu endp

; Return the offset of a gameObject into esi using an index
getGameObjectIndex proc, index:DWORD
	push eax
	push edx

	mov esi, index ; esi = index
	mov eax, gameObjectSize ; eax = gameObjectSize
	mul esi ; eax = index * gameObjectSize
	mov esi, eax ; esi = index * gameObjectSize
	add esi, ofst allGameObjects ; esi = [start of object array] + index * gameObjectSize

	pop edx
	pop eax
	ret 4
getGameObjectIndex endp

; Get the current leading invader and update LEADER flag
getLeader proc
	push eax
	push ecx
	push esi
	push edi

	cmp SCORE, 55 ; Make sure we aren't fucking up shit
	jne SOMEONE_ALIVE
	ret
	SOMEONE_ALIVE: ; Continue if we aren't fucking up shit

	; Find the first enemy alive
	xor ecx, ecx
	mov esi, ofst allGameObjects
	FIND_INITIAL:
		cmp DWORD ptr [esi + go_exists], TRUE ; Check if enemy is alive
		je FOUND_INITIAL ; If so continue w/ code
		add esi, gameObjectSize ; Next object
		inc ecx ; else check next enemy
	FOUND_INITIAL:
	inc ecx ; incease ecx because we don't need to compare the first enemy to himself
	mov edi, esi ; I use esi late so put the current potential leader into edi

	invoke getGameObjectIndex, ecx ; Get the initial index
	.while ecx < 55 ; Loop over all enemies

		cmp DWORD ptr [esi + go_exists], FALSE ; Is it alive?
		je CONTINUE_LEADER_SEARCH_LOOP

		cmp DWORD ptr [esi + go_points], 0 ; Is it even an enemy?
		je CONTINUE_LEADER_SEARCH_LOOP
			
		.if MOVE_LEFT == TRUE ; Move left
			; Am I the leftmostsome?
			mov eax, DWORD ptr [esi + go_x]
			.if eax < DWORD ptr [edi + go_x]
				;I am more left
				mov edi, esi
			.endif
		.else ; Move right
			; Am I the rightmostsome?
			mov eax, DWORD ptr [esi + go_x]
			.if DWORD ptr eax > DWORD ptr [edi + go_x]
				;I am more right
				mov edi, esi
			.endif
		.endif
		CONTINUE_LEADER_SEARCH_LOOP:
		add esi, gameObjectSize
		inc ecx
	.endw

	mov LEADER, edi ; Update the LEADER flag

	pop edi
	pop esi
	pop ecx
	pop eax
	ret
getLeader endp

; Change the game stage to Stage_GAMEOVER - the player lost
playerLost proc, object:DWORD
	mov GAME_STAGE, Stage_GAMEOVER	
	ret 4
playerLost endp

; Run this function to control the enemies (TODO more cleanup)
basicEnemyAi proc, object:DWORD
	pushad
	
	mov ebx, object ; can't use object in indexing so insert it into ebx

	; ~~~ move the enemy ~~~

	.if LEADER_SPOKE == FALSE ; Leader didn't speak

		mov edi, LEADER ; get the leader from memory

		; Let the leader speak (edi)
		.if MOVE_LEFT == TRUE
			mov ecx, 50
			sub ecx, enemy_width
			.if DWORD ptr [edi + go_x] < ecx ; Check leader position, change flags if needed
				mov MOVE_LEFT, FALSE
				mov JUMP_DOWN, TRUE
				invoke getLeader ; Get the leader because direction has changed
			.endif
		.else
			.if DWORD ptr [edi + go_x] > 950 ; Check leader position, change flags if needed
				mov MOVE_LEFT, TRUE
				mov JUMP_DOWN, TRUE
				invoke getLeader ; Get the leader because direction has changed
			.endif
		.endif
		mov LEADER_SPOKE, TRUE
	.endif
	
	xor eax, eax ; Set freqency
	mov al, INVADER_SPEED
	mov DWORD ptr [ebx + go_xFrq], eax

	; Set speed
	mov DWORD ptr [ebx + go_xV], 1
	.if MOVE_LEFT == TRUE
		neg DWORD ptr [ebx + go_xV] ; -1
	.endif

	.if JUMP_DOWN == TRUE ; Move one row down and check for player losing
		add DWORD ptr [ebx + go_y], enemy_height
		.if DWORD ptr [ebx + go_y] >= 420
			mov GAME_STAGE, Stage_GAMEOVER ; The invaders are too low
		.endif
	.endif

	; ~~~ shoot bullets ~~~

	invoke generateRandom ; Generate a random number to decide if to shoot or not
	invoke modulu, eax, 3500
	cmp eax, 0 ; eax % 3500 == 0
	jne EXIT_BE_AI
	invoke modulu, FRAME_COUNT, 1200
	cmp eax, 0
	jbe EXIT_BE_AI

	; 1:3500 chance to get here

	mov ecx, 0
	mov esi, ofst allGameObjects
	CHECK_BULLET_SHOOTING:
		cmp DWORD ptr [esi + go_exists], FALSE
		je CONTINUE_CBS 
		mov eax, [esi + go_x]
		sub eax, [ebx + go_x]
		cmp eax, 1
		jg CONTINUE_CBS
		mov eax, [esi + go_y]
		cmp eax, [ebx + go_y]
		ja EXIT_BE_AI
		CONTINUE_CBS:
		add esi, gameObjectSize
		inc ecx
	cmp ecx, 55
	jne CHECK_BULLET_SHOOTING

	mov al, BULLET_AMOUNT ; The amount of bullets alive
	cmp al, 15 ; BULLETS_ALIVE >= 15
	jae EXIT_BE_AI
	inc al
	mov BULLET_AMOUNT, al ; update bullet amount
 
	mov ecx, 55
	invoke getGameObjectIndex, 55
	FIND_VACANT_BULLET:
		cmp DWORD ptr [esi + go_exists], FALSE
		je BULLET_FOUND
		add esi, gameObjectSize
		inc ecx
	cmp ecx, 70
	jne FIND_VACANT_BULLET
	BULLET_FOUND:
	mov DWORD ptr [esi + go_exists], TRUE ; Make bullet exist
	mov eax, [ebx + go_x]
	mov [esi + go_x], eax ; Make bullet same x as shooter
	mov eax, [ebx + go_y]
	add eax, 35
	mov [esi + go_y], eax ; Make bullet same y as shooter

	EXIT_BE_AI:
	popad
	ret 4
basicEnemyAi endp

; The default collision function for game objects
defaultCollisionFunc proc, object:DWORD
	push ebx

	mov ebx, object
	mov DWORD ptr [ebx + go_exists], FALSE ; set the object exists variable to false

	pop ebx
	ret 4
defaultCollisionFunc endp

; The collision function that runs when a bullet hits an enemy
enemyCollisionFunc proc, object:DWORD
	push ebx

	mov ebx, object
	mov DWORD ptr [ebx + go_exists], FALSE ; set the object exists variable to false
	inc SCORE ; Increase the player score

	pop ebx
	ret 4
enemyCollisionFunc endp

; The collision function that runs when something hits a brick
brickCollisionFunc proc, object:DWORD
	push ebx

	mov ebx, object
	cmp DWORD ptr [ebx + go_sprite], ofst Brick1hp ; Do I have 1 hp currently?
	je DIE ; If so jump do DIE
	add DWORD ptr [ebx + go_sprite], imageObjectSize ; Increase my sprite value by Img<> struct size so that we will now point to the next image
	jmp EXIT_FUNC ; Exit
	DIE:
	mov DWORD ptr [ebx + go_exists], FALSE ; Set the exists variable of this brick to false

	EXIT_FUNC:
	pop ebx
	ret 4
brickCollisionFunc endp

; The collision function that runs when something hits a enemy bullet
enemyBulletCollision proc, object:DWORD
	push eax
	push ebx

	mov ebx, object
	mov al, BULLET_AMOUNT ; al = BULLET_AMOUNT
	dec al ; al = BULLET_AMOUNT - 1
	mov BULLET_AMOUNT, al ; BULLET_AMOUNT -= 1
	
	mov DWORD ptr [ebx + go_exists], FALSE ; Kill this bullet
	
	pop ebx
	pop eax
	ret 4
enemyBulletCollision endp

; Check the collision from one object to all the others objects
checkCollision proc, object:DWORD
	push ebx

	mov ebx, object

	; Exit the function if the object shouldn't check collision
	cmp DWORD ptr [ebx + go_coll], FALSE
	je FINISH_COLLISION

	; Exit if the object is dead
	cmp DWORD ptr [ebx + go_exists], FALSE
	je FINISH_COLLISION

	; We are officially inside the function, push some extra registers
	push ecx
	push edx

	xor ecx, ecx
	mov esi, ofst allGameObjects
	COLLISION_LOOP_OVER_OBJECTS: ; Loop over all game objects
		cmp DWORD ptr [esi + go_exists], FALSE ; Check if the object doesn't exists
		je CONTINUE_COLLISION_LOOP ; If so skip it
		cmp esi, ebx ; Check if the refrece object is the same object as the one being checked
		je CONTINUE_COLLISION_LOOP ; If so skip it

		mov eax, [ebx + go_x] ; xL of checker
		add eax, [ebx + go_htbxX] ; xH of checker
		mov edx, [esi + go_x] ; xL of checked
		add edx, [esi + go_htbxX] ; xH of checked
		.if DWORD ptr [ebx + go_x] <= edx && eax > [esi + go_x]
			jmp CHECK_COLLISION_Y
		.endif
		jmp CONTINUE_COLLISION_LOOP

		CHECK_COLLISION_Y:

		mov eax, [ebx + go_y] ; yL of checker
		add eax, [ebx + go_htbxY] ; yH of checker 
		mov edx, [esi + go_y] ; yL of checked
		add edx, [esi + go_htbxY] ; yH of checked
		.if DWORD ptr [ebx + go_y] <= edx && eax > [esi + go_y]
			jmp COLLISION_DETECTED
		.endif
		jmp CONTINUE_COLLISION_LOOP

		COLLISION_DETECTED:

		; Call the collision functions of the checker and checked
		push esi
		call DWORD ptr [esi + go_collFunc]
		push ebx
		call DWORD ptr [ebx + go_collFunc]
		jmp FINISH_COLLISION ; Exit
		
		CONTINUE_COLLISION_LOOP:
		add esi, gameObjectSize
		inc ecx
	cmp ecx, 112
	jne COLLISION_LOOP_OVER_OBJECTS

	pop edx
	pop ecx

	FINISH_COLLISION:
	pop ebx
	ret 4
checkCollision endp

; Handle a game object in that order: AI -> Movement -> Draw
handleGameObject proc, object:DWORD
	push ebx
	push eax

	mov ebx, object
	cmp DWORD ptr [ebx + go_exists], TRUE ; Check if object exists
	jne FINISH_HANDLING ; If not then don't handle it

	; Run the AI of the object
	cmp DWORD ptr [ebx + go_ai], 0
	je NO_AI
	push ebx
	call DWORD ptr [ebx + go_ai]
	NO_AI:
	
	; move the object (x)
	cmp DWORD ptr [ebx + go_xV], 0 ; If velocity is 0 don't move
	je HANDLE_Y_MOVEMENT
	invoke modulu, FRAME_COUNT, [ebx + go_xFrq] ; Check if this is a frame you should mive at
	.if eax == 0
		mov eax, [ebx + go_xV] ; If so move
	.else
		jmp HANDLE_Y_MOVEMENT ; Otherwise go the the Y movement
	.endif
	; Check if we didn't move too far with x
	add DWORD ptr [ebx + go_x], eax
	cmp DWORD ptr [ebx + go_x], 0
	jl CANT_GO_FURTHER_X
	mov eax, [ebx + go_htbxX]
	add eax, [ebx + go_x]
	cmp eax, 1000
	jg CANT_GO_FURTHER_X
	jmp HANDLE_Y_MOVEMENT

	CANT_GO_FURTHER_X:
	mov eax, [ebx + go_xV]
	sub DWORD ptr [ebx + go_x], eax

	 ; Move object (y) - Works the same way as x moving does
	HANDLE_Y_MOVEMENT:
	cmp DWORD ptr [ebx + go_yV], 0
	je DRAW_OBJECT
	invoke modulu, FRAME_COUNT, [ebx + go_yFrq]
	.if eax == 0
		mov eax, [ebx + go_yV]
	.else
		jmp DRAW_OBJECT
	.endif
	add DWORD ptr [ebx + go_y], eax
	cmp DWORD ptr [ebx + go_y], 0
	jl CANT_GO_FURTHER_Y
	mov eax, [ebx + go_htbxY]
	add eax, [ebx + go_y]
	cmp eax, 600
	jg CANT_GO_FURTHER_Y
	jmp DRAW_OBJECT

	CANT_GO_FURTHER_Y:
	push ebx
	call DWORD ptr [ebx + go_collFunc]
	jmp FINISH_HANDLING

	DRAW_OBJECT:
	invoke drd_imageDraw, [ebx + go_sprite], [ebx + go_x], [ebx + go_y] ; Draw the object

	FINISH_HANDLING:
	pop eax
	pop ebx
	ret 4
handleGameObject endp

; Handle all key presses possible in all game stages
keyhandle proc, keycode:DWORD

	; key right = 39
	; key left = 37
	; spacebar = 20h
	; R = 52h
	; E = 45h

	; Make sure I'm using the correct keyset for the menu and game
	cmp GAME_STAGE, Stage_MENU
	je menuKeys
	cmp GAME_STAGE, Stage_GAMEOVER
	je redirectionKeys
	cmp GAME_STAGE, Stage_WIN
	je redirectionKeys

	;#region Key handling during game

	cmp keycode, 39
	jne NOT_KEY_RIGHT
	
	; The right arrow key is pressed (move right):
	mov playerObject.xVelocity, playerSpeed

	jmp NO_KEY_MATCH
	NOT_KEY_RIGHT:
	cmp keycode, 37
	jne NOT_KEY_LEFT

	; The left arrow key is pressed (move left):
	mov playerObject.xVelocity, -playerSpeed

	jmp NO_KEY_MATCH
	NOT_KEY_LEFT:
	cmp keycode, 32
	jne NO_KEY_MATCH

	; Spacebar is pressed (shoot bullet):
	cmp playerBullet.exists, TRUE
	je NO_KEY_MATCH

	push eax
	push edx

	mov playerBullet.exists, TRUE						; Make the bullet exist
	mov eax, playerObject.hitBoxXOffset					; eax = player width
	shr eax, 1											; eax = player width / 2
	add eax, playerObject.x								; eax = player center x pos
	mov edx, playerBullet.hitBoxXOffset					; edx = bullet width
	shr edx, 1											; edx = bullet width / 2
	sub eax, edx										; eax = player x center pos adjusted for bullet hitbox
	mov playerBullet.x, eax								; bullet.x = player center x pos
	mov eax, playerObject.y								; eax = player y
	sub eax, 30											; eax = slightly above player y
	mov playerBullet.y, eax								; bullet.y = slightly above player y

	pop eax
	pop edx

	NO_KEY_MATCH:
	ret 4

	;#endregion

	;#region Key handling during menu

	menuKeys:
	
	cmp keycode, 20h
	jne MENU_NOT_SPACEBAR

	mov GAME_STAGE, Stage_PLAYING
	ret 4

	MENU_NOT_SPACEBAR:
	cmp keycode, 45h
	jne NO_MENU_KEY_MATCH

	mov GAME_STAGE, Stage_EXIT
	ret 4

	NO_MENU_KEY_MATCH:
	ret 4

	;#endregion

	;#Region key handling during lose or win

	redirectionKeys:

	cmp keycode, 52h
	je RETRY_GAME
	cmp keycode, 20h
	je TO_MENU
	ret 4

	RETRY_GAME:
	; The 'R' key is pressed (restart the game)
	mov GAME_STAGE, Stage_PLAYING
	ret 4

	TO_MENU:
	mov GAME_STAGE, Stage_MENU

	;#endregion

	ret 4
keyhandle endp

; Run at the startup of the program, overall this must be run only once
initGameStartup proc
	push ecx
	push esi

	; ~~~ Player setup ~~~

	mov playerObject.collisionFunc, ofst playerLost ; Player collision function
	mov playerObject.hitBoxXOffset, 132 ; Player width
	mov playerObject.hitBoxYOffset, 40 ; Player height

	; ~~~ Player bullet setup ~~~

	mov playerBullet.yVelocity, -1 ; Bullet moves at a speed of 1 upwards
	mov playerBullet.yFreq, 4 ; The bullet moves every 4 frames
	mov playerBullet.hitBoxXOffset, 13 ; The bullet width is 13
	mov playerBullet.hitBoxYOffset, 25 ; The bullet height is 25
	mov playerBullet.checkCollision, TRUE ; The bullet is a collision checker

	; ~~~ Enemy setup ~~~

	xor ecx, ecx
	ENEMY_SETUP_LOOP:
		invoke getGameObjectIndex, ecx ; Get the index

		mov DWORD ptr [esi + go_xFrq], 16 ; They move once every 16 frames
		mov DWORD ptr [esi + go_htbxX], enemy_width ; Width
		mov DWORD ptr [esi + go_htbxY], enemy_height ; Height
		mov DWORD ptr [esi + go_ai], ofst basicEnemyAi ; Set their commanding AI to basicEnemyAi(DWORD object)
		mov DWORD ptr [esi + go_points], 1 ; When an enemy dies he gives one point
		mov DWORD ptr [esi + go_collFunc], ofst enemyCollisionFunc ; Set collision function

		inc ecx
	cmp ecx, 55
	jne ENEMY_SETUP_LOOP

	; ~~~ Initilize enemy bullets ~~~

	ENEMY_BULLET_SETUP_LOOP:
		invoke getGameObjectIndex, ecx

		mov DWORD ptr [esi + go_coll], TRUE ; Enemy bullets check collision
		mov DWORD ptr [esi + go_htbxX], 13 ; width
		mov DWORD ptr [esi + go_htbxY], 25 ; height
		mov DWORD ptr [esi + go_yFrq], 12 ; Move once every 12 frames
		mov DWORD ptr [esi + go_yV], 1 ; Move 1 in the y axis each time
		mov DWORD ptr [esi + go_collFunc], ofst enemyBulletCollision ; Set collision function

		inc ecx
	cmp ecx, 70
	jne ENEMY_BULLET_SETUP_LOOP

	; ~~~ Initilize bricks ~~~

	BRICK_INIT_LOOP:
		invoke getGameObjectIndex, ecx

		mov DWORD ptr [esi + go_htbxX], 10 ; Width
		mov DWORD ptr [esi + go_htbxY], 10 ; Height
		mov DWORD ptr [esi + go_collFunc], ofst brickCollisionFunc ; Collision function
		
		inc ecx
	cmp ecx, 110
	jne BRICK_INIT_LOOP

	pop esi
	pop ecx
	ret
initGameStartup endp

; Run this everytime I want to restart/start a game session (TODO more cleanup)
initGame proc
	mov FRAME_COUNT, 0 ; Reset the frame count because a new game has started
	mov SCORE, 0 ; Reset the score
	; ~~~ Player setup ~~~
	mov playerObject.x, 434 ; Player x position
	mov playerObject.y, 500 ; Player y position
	mov playerObject.exists, TRUE ; The player starts out alive
	lea eax, Player_Still
	mov playerObject.sprite, eax ; The default player sprite
	; ~~~ Player bullet setup ~~~
	lea eax, Player_Bullet
	mov playerBullet.sprite, eax ; The default bullet sprite
	mov playerBullet.exists, FALSE

	; ~~~ Enemy setup ~~~
	mov INVADER_SPEED, 16
	xor ecx, ecx
	ENEMY_SETUP_LOOP:
		invoke getGameObjectIndex, ecx ; Get the index
		lea ebx, Enemy0
		mov [esi + go_sprite], ebx ; Set the enemy default sprite
		mov DWORD ptr [esi + go_exists], TRUE ; The enemies start out 

		; ~-~ Allocate the enemies on screen ~-~
		mov eax, ecx ; X
		inc eax ; increase by one so division by 0 won't exist
		invoke modulu, eax, 11 ; Get remainder
		mov ebx, enemy_width ; enemy_width * 2 is the distance between each thing
		shl ebx, 1
		mul ebx ; = enemy_width * 2 * ((ecx + 1) % 11)
		add eax, 60 ; add 60 to move the thing not to the rightest point on screen
		mov [esi + go_x], eax

		mov eax, ecx ; Y
		inc eax ; = ecx + 1
		invoke modulu, eax, 5
		mov ebx, enemy_height
		shl ebx, 1
		mul ebx ; = enemy_height * 2 * ((ecx + 1) % 5)
		add eax, 40
		mov [esi + go_y], eax

		inc ecx
	cmp ecx, 55
	jne ENEMY_SETUP_LOOP
	invoke getLeader ; Get the initial leader
	; ~~~ Initilize enemy bullets ~~~
	ENEMY_BULLET_SETUP_LOOP:
		invoke getGameObjectIndex, ecx

		lea ebx, EnemyBullet0
		mov DWORD ptr [esi + go_sprite], ebx
		mov DWORD ptr [esi + go_exists], FALSE

		inc ecx
	cmp ecx, 70
	jne ENEMY_BULLET_SETUP_LOOP
	; ~~~ Initilize bricks ~~~
	xor edi, edi

	BRICK_INIT_LOOP:
		invoke getGameObjectIndex, ecx

		lea ebx, Brick4hp
		mov DWORD ptr [esi + go_sprite], ebx
		mov DWORD ptr [esi + go_exists], TRUE

		; Set positions
		mov DWORD ptr [esi + go_x], baseBrickX
		mov DWORD ptr [esi + go_y], baseBrickY
		mov eax, [xOffsetFromBaseBrick + edi] 
		add DWORD ptr [esi + go_x], eax
		mov eax, [yOffsetFromBaseBrick + edi] 
		add DWORD ptr [esi + go_y], eax
		
		; Add x offset

		mov eax, ecx
		push ecx
		mov ecx, 10
		div ecx
		pop ecx
		sub eax, 7
		mov edx, 208
		mul edx
		add DWORD ptr [esi + go_x], eax

		add edi, 4
		.if edi == 40
			xor edi, edi
		.endif
		inc ecx
	cmp ecx, 110
	jne BRICK_INIT_LOOP
	ret
initGame endp

; Draw the currunt score (SCORE flag) using the lettres, maximun score is 255
drawScore proc, xPos:DWORD, yPos:DWORD
	pushad

	;#region hundrends

	xor edx, edx ; edx = 0
	xor eax, eax
	mov al, SCORE ; eax = SCORE
	mov ebx, 100
	div ebx ; eax = Math.floor(SCORE / 100)

	mov ebx, imageObjectSize ; ebx = 20
	mul ebx ; eax = 100's * 20
	mov ebx, eax ; ebx = 100's * 20
	add ebx, ofst numbersArray ; add origin to make offset correct

	invoke drd_imageDraw, ebx, xPos, yPos ; Draw

	;#endregion

	add xPos, 35

	;#region tens

	xor edx, edx ; edx = 0
	xor eax, eax
	mov al, SCORE ; eax = SCORE
	mov ebx, 10
	div ebx ; eax = Math.floor(SCORE / 10)
	push edx ; this contains SCORE % 10 which is needed for later
	invoke modulu, eax, 10 ; eax = Math.floor(SCORE / 10) % 10

	mov ebx, imageObjectSize ; ebx = 20
	mul ebx ; eax = 10's * 20
	mov ebx, eax ; ebx = 10's * 20
	add ebx, ofst numbersArray ; add origin to make offset correct

	invoke drd_imageDraw, ebx, xPos, yPos ; Draw

	;#endregion

	add xPos, 35
	
	;#region ones

	pop eax ; eax = SCORE % 10 which was pushed form edx earlier

	mov ebx, imageObjectSize ; ebx = 20
	mul ebx ; eax = 1's * 20
	mov ebx, eax ; ebx = 1's * 20
	add ebx, ofst numbersArray ; add origin to make offset correct

	invoke drd_imageDraw, ebx, xPos, yPos ; Draw

	;#endregion

	popad
	ret 8
drawScore endp

main proc
	
	;#region general setup

	; Create the window
	invoke drd_init, 1000, 600, 0
	; Set the key handler
	invoke drd_setKeyHandler, ofst keyhandle ; opTODO masm key input
	; Set window name
	invoke drd_setWindowTitle, ofst windowName
	; Load the images into RAM
	invoke drd_imageLoadFile, ofst d_Player_Still, ofst Player_Still
	invoke drd_imageLoadFile, ofst d_Player_Bullet, ofst Player_Bullet
	invoke drd_imageLoadFile, ofst d_Enemy0, ofst Enemy0
	invoke drd_imageLoadFile, ofst d_EnemyBullet0, ofst EnemyBullet0
	invoke drd_imageLoadFile, ofst d_Brick4hp, ofst Brick4hp
	invoke drd_imageLoadFile, ofst d_Brick3hp, ofst Brick3hp
	invoke drd_imageLoadFile, ofst d_Brick2hp, ofst Brick2hp
	invoke drd_imageLoadFile, ofst d_Brick1hp, ofst Brick1hp
	invoke drd_imageLoadFile, ofst d_background, ofst background
	invoke drd_imageLoadFile, ofst d_gameoverScreen, ofst gameoverScreen
	invoke drd_imageLoadFile, ofst d_mainMenu, ofst mainMenu
	invoke drd_imageLoadFile, ofst d_winScreen, ofst winScreen

	; Load the numbers
	mov ecx, 10 ; Loop 10 times (10 numbers)
	lea ebx, numbersArray ; The Img<> object location
	lea esi, d_numberBase ; The directory of the image
	LOAD_NUMBERS:
		push ecx
		invoke drd_imageLoadFile, esi, ebx ; Load the image
		pop ecx
		add ebx, imageObjectSize ; Shift one image in the array
		inc BYTE ptr [esi + numbersOfst] ; Change the ASCII value of byte 16 in the adress by one so '0' -> '1' -> '2' -> '3' -> ... -> '9'
	loop LOAD_NUMBERS

	; Startup all the game variables
	invoke initGameStartup
	
	;#endregion

	;#region menu

	menuSetup:

	; Draw the main menu screen
	invoke drd_imageDraw, ofst mainMenu, 0, 0
	invoke drd_flip

	menuLoop:
		invoke drd_processMessages
		cmp eax, 0
		je exitGame
	cmp GAME_STAGE, Stage_MENU
	je menuLoop
	cmp GAME_STAGE, Stage_EXIT
	je exitGame
	; I don't check for Stage_PLAYING because it's the third option and doesn't require a jump
	
	;#endregion

	;#region game

	gameSetup:
	invoke initGame
	gameLoop:
		invoke drd_imageDraw, ofst background, 0, 0 ; Draw the background over all existing items, thus making them invisible

		invoke drawScore, 0, 0 ; Draw the score for the player

		;#region handle objects loop (Handle movment + ai + drawing of all objects)
		xor ecx, ecx
		mov esi, ofst allGameObjects
		MAD_LOOP:
			push ecx
			push esi
			invoke handleGameObject, esi
			pop esi
			pop ecx
			add esi, gameObjectSize
			inc ecx
		cmp ecx, 112
		jne MAD_LOOP
		;#endregion

		;#region Collision detection
		xor ecx, ecx
		mov esi, ofst allGameObjects
		COLL_LOOP:
			push ecx
			push esi
			invoke checkCollision, esi 
			pop esi
			pop ecx
			add esi, gameObjectSize
			inc ecx
		cmp ecx, 112
		jne COLL_LOOP
		;#endregion

		;#region End of frame stuff

		cmp SCORE, 55
		je playerWonSetup

		mov ebx, LEADER
		cmp DWORD ptr [ebx + go_exists], TRUE
		je LEADER_ALIVE
		invoke getLeader
		LEADER_ALIVE:

		invoke drd_flip ; Draw all the things

		mov playerObject.xVelocity, 0 ; Nullify the player speed
		mov LEADER_SPOKE, FALSE ; Leader can't forsee the next frame, and therefor is silent
		mov JUMP_DOWN, FALSE ; Can't jump down twice

		invoke drd_processMessages ; Check keypresses
		cmp eax, 0
		je exitGame

		invoke modulu, FRAME_COUNT, 10000
		cmp eax, 0
		jne NO_INCREASE
			dec INVADER_SPEED
			cmp INVADER_SPEED, 0
			jne NO_INCREASE
			inc INVADER_SPEED
		NO_INCREASE:

		inc FRAME_COUNT ; Another frame bites the dust
		
		;#endregion

	cmp GAME_STAGE, Stage_PLAYING
	je gameLoop
	cmp GAME_STAGE, Stage_GAMEOVER
	je gameOverSetup
	; Third option is Stage_WIN which doesn't reqire a jump

	;#endregion

	;#region player won

	playerWonSetup:
	; Set stage
	mov GAME_STAGE, Stage_WIN
	; Draw the screen
	invoke drd_imageDraw, ofst winScreen, 0, 0
	invoke drawScore, 700, 400
	invoke drd_flip

	winLoop:
		invoke drd_processMessages
		cmp eax, 0
		je exitGame
	cmp GAME_STAGE, Stage_WIN
	je winLoop
	cmp GAME_STAGE, Stage_PLAYING
	je gameSetup
	cmp GAME_STAGE, Stage_MENU
	je menuSetup

	;#endregion

	;#region gameover

	gameOverSetup:

	; Draw game over screen
	invoke drd_imageDraw, ofst gameoverScreen, 0, 0
	invoke drawScore, 700, 400
	invoke drd_flip

	; ~~~ Game over loop ~~~
	gameOver:
		invoke drd_processMessages
		cmp eax, 0
		je exitGame
	cmp GAME_STAGE, Stage_GAMEOVER
	je gameOver
	cmp GAME_STAGE, Stage_PLAYING
	je gameSetup
	cmp GAME_STAGE, Stage_MENU
	je menuSetup
	
	;#endregion

	exitGame:

	invoke ExitProcess, 0 
	ret
main endp

end main
