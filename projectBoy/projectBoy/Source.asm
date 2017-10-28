include /masm32/include/masm32rt.inc

include drd.inc
includelib drd.lib

.686

.data

; ----------------- equ declaration ----------------

Stage_MENU equ 0 ; Stage enum
Stage_PLAYING equ 1

FALSE equ 0 ; Boolean variables
TRUE equ 1

ofst equ offset ; I'm lazy

playerSpeed equ 8 ; Player stuff

gameObjectSize equ 56
go_y equ 0 ; Object charachteristics offsets
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

enemy_width equ 20 ; Enemy sizes (hitbox)
enemy_height equ 30

baseBrickX equ 168 ; For brick intialazation
baseBrickY equ 450

; ---------------- Object defenition ----------------

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

; ----------- Image location declaration -----------

d_Player_Still BYTE "Sprites/Player/Player_Regular.bmp", 0
d_Player_Bullet BYTE "Sprites/Player/Player_Bullet.bmp", 0
d_Enemy0 BYTE "Sprites/Enemies/Enemy0.bmp", 0
d_EnemyBullet0 BYTE "Sprites/Enemies/Enemy_Bullet.bmp", 0
d_Brick4hp BYTE "Sprites/Shields/Brick4hp.bmp", 0
d_Brick3hp BYTE "Sprites/Shields/Brick3hp.bmp", 0
d_Brick2hp BYTE "Sprites/Shields/Brick2hp.bmp", 0
d_Brick1hp BYTE "Sprites/Shields/Brick1hp.bmp", 0

; ------------ Image memory decleration -------------

Player_Still Img<>
Player_Bullet Img<>
Enemy0 Img<>
EnemyBullet0 Img<>
Brick4hp Img<>
Brick3hp Img<>
Brick2hp Img<>
Brick1hp Img<>

; --------------- Object Declaration ---------------

allGameObjects GameObject 110 dup (<?>)
playerObject GameObject<>
playerBullet GameObject<>

; ----------- Brick location declaration -----------
;
; each @ is 10x10 pixels, - are defined by surrounding @ or markings
; coordinates are adjusted from base point (marked in drawing)
;
;---------------------------------
;----------@@@@----------@@@@-----
;|---168--|@@@@|---168--|@@@@-----
;----------@--@----------@--@-----
;-----base-^----------------------

;baseBrickX equ 168 (actual declaration - lines 41 and 42)
;baseBrickY equ 450

; Y Offest array

yOffsetFromBaseBrick DWORD 0, 0, -10, -10, -10, -10, -20, -20, -20, -20

; X offset array:

xOffsetFromBaseBrick DWORD 0, 30, 0, 10, 20, 30, 0, 10, 20, 30


; ---------------------- flags ---------------------


MOVE_LEFT BYTE FALSE ; Are the invaders moving left? 
LEADER_SPOKE BYTE FALSE ; Did the leader say his word? 
JUMP_DOWN BYTE FALSE ; Should we go lower?
SPEED_STAGE BYTE 0 ; How fast we go?
BULLET_AMOUNT BYTE 0 ; How many bullets alive now?
GAME_STAGE DWORD Stage_PLAYING ; Stage_MENU & Stage_PLAYING ( TODO when done with game change to Stage.MENU)
FRAME_COUNT DWORD 0 ; How many frames have passed?

.code

generateRandom proc; Generate a DWORD random number and insert that into eax
	rdseed ax
	shl eax, 4
	rdseed ax
	ret
generateRandom endp

modulu proc, firstElement:DWORD, secondElement:DWORD
	push edx

	xor edx, edx
	mov eax, firstElement
	div secondElement
	mov eax, edx

	pop edx
	ret 8
modulu endp

getGameObjectIndex proc, index:DWORD
	push eax
	push edx
	mov esi, index ; Get the the index of the current object
	mov eax, gameObjectSize
	mul esi
	mov esi, eax
	add esi, ofst allGameObjects
	pop edx
	pop eax
	ret 4
getGameObjectIndex endp

basicEnemyAi proc, object:DWORD ; TODO make sure player losesy
	push ebx ; I use these registes
	push ecx
	push esi	
	push edi
	push eax
	
	mov ebx, object ; can't use object in indexing so insert it into ebx

	; ~~~ move the enemy ~~~

	.if LEADER_SPOKE == FALSE ; Leader didn't speak

		mov ecx, 1 ; Setup first default and loop
		invoke getGameObjectIndex, 0
		mov edi, esi

		.while ecx < 55 ; Loop over all enemies

			invoke getGameObjectIndex, ecx ; Get the index

			cmp DWORD ptr [esi + go_exists], FALSE ; Is it alive?
			je CONTINUE_LEADER_SEARCH_LOOP

			cmp DWORD ptr [esi + go_points], 0 ; Is it even an enemy?
			je CONTINUE_LEADER_SEARCH_LOOP
			
			push eax ; I use eax for a bit here
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
			pop eax

			CONTINUE_LEADER_SEARCH_LOOP:
			inc ecx
		.endw

		; Let the leader speak (edi)
		.if MOVE_LEFT == TRUE
			mov ecx, 50
			sub ecx, enemy_width
			.if DWORD ptr [edi + go_x] < ecx ; Check leader position, change flags if needed
				mov MOVE_LEFT, FALSE
				mov JUMP_DOWN, TRUE
			.endif
		.else
			.if DWORD ptr [edi + go_x] > 950 ; Check leader position, change flags if needed
				mov MOVE_LEFT, TRUE
				mov JUMP_DOWN, TRUE
			.endif
		.endif
		mov LEADER_SPOKE, TRUE
	.endif
	
	; Move the dudes
	.if MOVE_LEFT == FALSE
		mov DWORD ptr [ebx + go_xV], 1
	.else ; MOVE_LEFT == TRUE
		mov DWORD ptr [ebx + go_xV], -1
	.endif

	.if JUMP_DOWN == TRUE ; Move one row down
		add DWORD ptr [ebx + go_y], enemy_height
	.endif

	; ~~~ shoot bullets ~~~

	invoke generateRandom ; Generate a random number to decide if to shoot or not
	invoke modulu, eax, 10000
	cmp eax, 0 ; eax % 10000 == 0
	jne EXIT_BE_AI
	invoke modulu, FRAME_COUNT, 301
	cmp eax, 0
	jbe EXIT_BE_AI

	; 1:10000 chance to get here

	mov ecx, 0
	CHECK_BULLET_SHOOTING:
		invoke getGameObjectIndex, ecx
		cmp DWORD ptr [esi + go_exists], FALSE
		je CONTINUE_CBS
		mov eax, [esi + go_x]
		cmp eax, [ebx + go_x]
		jne CONTINUE_CBS
		mov eax, [esi + go_y]
		cmp eax, [ebx + go_y]
		ja EXIT_BE_AI
		CONTINUE_CBS:
		inc ecx
	cmp ecx, 55
	jne CHECK_BULLET_SHOOTING

	mov al, BULLET_AMOUNT ; The amount of bullets alive
	cmp al, 15 ; BULLETS_ALIVE >= 15
	jae EXIT_BE_AI
	inc al
	mov BULLET_AMOUNT, al ; update bullet amount

	mov ecx, 55
	FIND_VACANT_BULLET:
		invoke getGameObjectIndex, ecx 	; Get potential bullet index
		cmp DWORD ptr [esi + go_exists], FALSE
		je BULLET_FOUND
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
	pop eax
	pop edi
	pop esi
	pop ecx
	pop ebx
	ret 4
basicEnemyAi endp

defaultCollisionFunc proc, object:DWORD ; TODO add points when you ded
	push ebx
	mov ebx, object
	mov DWORD ptr [ebx + go_exists], FALSE
	pop ebx
	ret 4
defaultCollisionFunc endp

enemyBulletCollision proc, object:DWORD
	push eax
	push ebx

	mov ebx, object ; The object which is dying
    xor eax, eax ; eax = 0
	add al, BULLET_AMOUNT ; eax = BULLET_AMOUNT
	dec eax ; eax = BULLET_AMOUNT - 1
	mov BULLET_AMOUNT, al
	
	invoke defaultCollisionFunc, ebx
	
	pop ebx
	pop eax
	ret 4
enemyBulletCollision endp

checkCollision proc, object:DWORD
	push ebx
	mov ebx, object
	cmp DWORD ptr [ebx + go_coll], FALSE
	je FINISH_COLLISION
	cmp DWORD ptr [ebx + go_exists], FALSE
	je FINISH_COLLISION

	xor ecx, ecx
	push edx
	COLLISION_LOOP_OVER_OBJECTS: ; Loop over all game objects
		invoke getGameObjectIndex, ecx
		cmp DWORD ptr [esi + go_exists], FALSE ; Check if the object exists
		je CONTINUE_COLLISION_LOOP
		cmp esi, ebx ; The object I'm checking is the same as the refrence object
		je CONTINUE_COLLISION_LOOP 

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

		push esi
		call DWORD ptr [esi + go_collFunc]
		push ebx
		call DWORD ptr [ebx + go_collFunc]
		
		CONTINUE_COLLISION_LOOP:
		inc ecx
	cmp ecx, 112
	jne COLLISION_LOOP_OVER_OBJECTS
	pop edx

	FINISH_COLLISION:
	pop ebx
	ret 4
checkCollision endp

handleGameObject proc, object:DWORD
	push ebx

	mov ebx, object
	cmp DWORD ptr [ebx + go_exists], TRUE ; Check if object exists
	jne FINISH_HANDLING

	cmp DWORD ptr [ebx + go_ai], 0 ; Run the AI of the object
	je NO_AI
	push ebx
	call DWORD ptr [ebx + go_ai]
	NO_AI:
	
	cmp DWORD ptr [ebx + go_xV], 0 ; move the object (x)
	je HANDLE_Y_MOVEMENT
	invoke modulu, FRAME_COUNT, [ebx + go_xFrq]
	.if eax == 0
		mov eax, [ebx + go_xV]
	.else
		jmp HANDLE_Y_MOVEMENT
	.endif
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

	HANDLE_Y_MOVEMENT: ; Move object (y)
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

	DRAW_OBJECT:
	invoke drd_imageDraw, [ebx + go_sprite], [ebx + go_x], [ebx + go_y] ; Draw the object

	FINISH_HANDLING:
	pop ebx
	ret 4
handleGameObject endp

keyhandle proc, keycode:DWORD
	
	; key right = 39
	; key left = 37
	; spacebar = 20

	cmp GAME_STAGE, Stage_MENU ; Make sure I'm using the correct keyset for the menu and game
	je menuKeys
	
	cmp keycode, 39
	jne NOT_KEY_RIGHT
	
	; The right arrow key is pressed:
	mov playerObject.xVelocity, playerSpeed

	jmp NO_KEY_MATCH
	NOT_KEY_RIGHT:
	cmp keycode, 37
	jne NOT_KEY_LEFT

	; The left arrow key is pressed:
	mov playerObject.xVelocity, -playerSpeed

	jmp NO_KEY_MATCH
	NOT_KEY_LEFT:
	cmp keycode, 32
	jne NO_KEY_MATCH

	; Spacebar is pressed:
	cmp playerBullet.exists, TRUE
	je NO_KEY_MATCH

	; Shoot bullet TODO show the bullet slightly to the left adjusted by it's own hitbox
	mov playerBullet.exists, TRUE
	mov eax, playerObject.hitBoxXOffset
	shr eax, 1
	add eax, playerObject.x
	mov playerBullet.x, eax
	mov eax, playerObject.y
	sub eax, 30
	mov playerBullet.y, eax

	NO_KEY_MATCH:
	ret 4

	menuKeys:

	ret 4
keyhandle endp

main proc
	
	; general setup
	invoke drd_init, 1000, 600, 0
	invoke drd_setKeyHandler, ofst keyhandle ; TODO masm key input
	invoke drd_imageLoadFile, ofst d_Player_Still, ofst Player_Still
	invoke drd_imageLoadFile, ofst d_Player_Bullet, ofst Player_Bullet
	invoke drd_imageLoadFile, ofst d_Enemy0, ofst Enemy0
	invoke drd_imageLoadFile, ofst d_EnemyBullet0, ofst EnemyBullet0
	invoke drd_imageLoadFile, ofst d_Brick4hp, ofst Brick4hp
	invoke drd_imageLoadFile, ofst d_Brick3hp, ofst Brick3hp
	invoke drd_imageLoadFile, ofst d_Brick2hp, ofst Brick2hp
	invoke drd_imageLoadFile, ofst d_Brick1hp, ofst Brick1hp
	
	jmp gameSetup ; TODO Remove when game finished

	menuSetup:

	menuLoop:
		invoke drd_pixelsClear, 0

		invoke drd_processMessages
	jmp menuLoop
	
	gameSetup:
	
	mov FRAME_COUNT, 0 ; Reset the frame count because a new game has started
	; ~~~ Player setup ~~~
	mov playerObject.x, 434 ; Player x position
	mov playerObject.y, 500 ; Player y position
	mov playerObject.hitBoxXOffset, 132 ; Player width
	mov playerObject.hitBoxYOffset, 40 ; Player height
	mov playerObject.exists, TRUE ; The player starts out alive
	lea eax, Player_Still
	mov playerObject.sprite, eax ; The default player sprite
	; ~~~ Player bullet setup ~~~
	lea eax, Player_Bullet
	mov playerBullet.sprite, eax ; The default bullet sprite
	mov playerBullet.yVelocity, -1 ; Bullet moves at a speed of 1 upwards
	mov playerBullet.yFreq, 4 ; The bullet moves every 4 frames
	mov playerBullet.hitBoxXOffset, 13 ; The bullet width is 13
	mov playerBullet.hitBoxYOffset, 25 ; The bullet height is 25
	mov playerBullet.checkCollision, TRUE ; The bullet is a collision checker

	; ~~~ Enemy setup ~~~
	xor ecx, ecx
	ENEMY_SETUP_LOOP:
		invoke getGameObjectIndex, ecx ; Get the index
		lea ebx, Enemy0
		mov [esi + go_sprite], ebx ; Set the enemy default sprite
		mov DWORD ptr [esi + go_exists], TRUE ; The enemies start out alive
		mov DWORD ptr [esi + go_xFrq], 16 ; They move once every 16 frames
		mov DWORD ptr [esi + go_htbxX], enemy_width ; Width
		mov DWORD ptr [esi + go_htbxY], enemy_height ; Height
		mov DWORD ptr [esi + go_ai], ofst basicEnemyAi ; Set their commanding AI to basicEnemyAi(DWORD object)
		mov DWORD ptr [esi + go_points], 1 ; When an enemy dies he gives one point
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
	; ~~~ Initilize enemy bullets ~~~
	ENEMY_BULLET_SETUP_LOOP:
		invoke getGameObjectIndex, ecx

		lea ebx, EnemyBullet0
		mov DWORD ptr [esi + go_sprite], ebx
		mov DWORD ptr [esi + go_coll], TRUE
		mov DWORD ptr [esi + go_htbxX], 13
		mov DWORD ptr [esi + go_htbxY], 25
		mov DWORD ptr [esi + go_yFrq], 12
		mov DWORD ptr [esi + go_yV], 1
		mov DWORD ptr [esi + go_collFunc], ofst enemyBulletCollision

		inc ecx
	cmp ecx, 70
	jne ENEMY_BULLET_SETUP_LOOP
	; ~~~ Initilize bricks ~~~
	xor edi, edi
	BRICK_INIT_LOOP:
		invoke getGameObjectIndex, ecx

		; TODO set collision func

		lea ebx, Brick4hp
		mov DWORD ptr [esi + go_sprite], ebx
		mov DWORD ptr [esi + go_exists], TRUE
		mov DWORD ptr [esi + go_htbxX], 10
		mov DWORD ptr [esi + go_htbxY], 10

		; Set positions
		mov DWORD ptr [esi + go_x], baseBrickX
		mov DWORD ptr [esi + go_y], baseBrickY
		mov eax, [xOffsetFromBaseBrick + edi] 
		add DWORD ptr [esi + go_x], eax
		mov eax, [yOffsetFromBaseBrick + edi] 
		add DWORD ptr [esi + go_y], eax
		
		; Add x offset

		mov eax, ecx ; TODO fix
		push ecx
		mov ecx, 10
		div ecx
		pop ecx
		sub eax, 7
		mov edx, baseBrickX
		mul edx
		add DWORD ptr [esi + go_x], eax

		add edi, 4
		.if edi == 44
			xor edi, edi
		.endif
		inc ecx
	cmp ecx, 110
	jne BRICK_INIT_LOOP


	gameLoop:
		invoke drd_pixelsClear, 0

		; Handle movment + ai + drawing of all objects
		xor ecx, ecx
		MAD_LOOP:
			push ecx
			invoke getGameObjectIndex, ecx
			invoke handleGameObject, esi
			pop ecx
			inc ecx
		cmp ecx, 112
		jne MAD_LOOP

		; Collision detection
		xor ecx, ecx
		COLL_LOOP:
			push ecx
			invoke getGameObjectIndex, ecx
			invoke checkCollision, esi
			pop ecx
			inc ecx
		cmp ecx, 112
		jne COLL_LOOP

		; End of frame stuff
		invoke drd_flip ; Draw all the things
		mov playerObject.xVelocity, 0 ; Nullify the player speed
		mov LEADER_SPOKE, FALSE
		mov JUMP_DOWN, FALSE
		invoke drd_processMessages ; Check keypresses
		inc FRAME_COUNT ; Another frame bites the dust
	jmp gameLoop

	exitGame:

	ret
main endp

end main