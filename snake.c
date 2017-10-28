#include "stdafx.h"
#include <stdint.h>

//Libraries for win test:
#include <time.h>
#include <windows.h> 

//Constants
#define XSIZE 30
#define YSIZE 20
#define SNAKE 1
#define SNAKE_HEAD 2
#define SNAKE_TAIL 3
#define FOOD 4
#define MAX_LENGTH 100
enum { RIGHT = -1, UP = 1, LEFT = -2, DOWN = 2};

//Gamefield
uint8_t map[XSIZE][YSIZE];

//Circular buffers for snake coordinates
uint8_t snake_x[MAX_LENGTH];
uint8_t snake_y[MAX_LENGTH];
int		head_index = 0;
uint8_t length = 4;

//Food coordinates
uint8_t food_x;
uint8_t food_y;

//Head direction and coordinates
int		direction = RIGHT;	//Kígyó iránya
int		x_position = 10;
int		y_position = 10;

//Control variables
uint8_t level = 1;			//Sebesség
uint8_t food_eaten = 0;		//Megevett kaja
uint8_t alive = 1;			//Játék megy-e?

void draw_pixel(uint8_t x, uint8_t y, uint8_t value) {}

void timer_callback() {
	int offset, index;

	//Check wall collision
	switch (direction) {
	case RIGHT: {
		x_position++;
		if (x_position >= XSIZE) {
			alive = 0;
			return;
		}
		break;
	}
	case UP: {
		y_position--;
		if (y_position < 0) {
			alive = 0;
			return;
		}
		break;
	}
	case LEFT: {
		x_position--;
		if (x_position < 0) {
			alive = 0;
			return;
		}
		break;
	}
	case DOWN: {
		y_position++;
		if (y_position >= YSIZE) {
			alive = 0;
			return;
		}
		break;
	}
	default: return;
	}

	//Check self collision
	if (map[x_position][y_position] == SNAKE) {
		alive = 0;
		return;
	}

	//Save offset
	offset = length - 1;

	//Check food
	if (map[x_position][y_position] == FOOD) {
		if (++length >= MAX_LENGTH) {
			alive = 2;	//Winner
			return;
		}
		//Generate new food
		while (map[food_x][food_y] != 0) {
			food_x = rand() % XSIZE;
			food_y = rand() % YSIZE;
		}
		map[food_x][food_y] = FOOD;
	}
	else {
		//Remove tail
		index = head_index - offset;
		if (index < 0) index = index + MAX_LENGTH;
		map[snake_x[index]][snake_y[index]] = 0;
	}

	//Add new head
	if (++head_index >= MAX_LENGTH)
		head_index = 0;
	snake_x[head_index] = x_position;
	snake_y[head_index] = y_position;
	map[x_position][y_position] = SNAKE;
}

int main() {
	int i, j;			//ciklusváltozók
	int offset, index;
	int new_dir = RIGHT;
	int iteration;

	//Initialise clear map
	for (j = 0; j < YSIZE; j++) {
		for (i = 0; i < XSIZE; i++) {
			map[i][j] = 0;
		}
	}

	//Initialise snake (using circular buffer)
	for (i = 0; i < length; i++) {
		snake_x[i] = ++x_position;
		snake_y[i] = y_position;
	}
	head_index = length - 1;

	//Draw snake
	for (offset = 0; offset < length; offset++) {
		index = head_index - offset;
		if (index < 0) index = index + MAX_LENGTH;
		map[snake_x[index]][snake_y[index]] = SNAKE;
	}

	/*//Generate random new food
	srand(time(NULL));
	do {
		food_x = rand() % XSIZE;
		food_y = rand() % YSIZE;
	} while (map[food_x][food_y] != 0);
	map[food_x][food_y] = FOOD;*/

	//Constant init food for testing
	food_x = 15;
	food_y = 15;
	map[food_x][food_y] = FOOD;

	//init_pheriperals();
	//start_timer();

	//---------------------------------------
	//		Test in command window
	//---------------------------------------
	iteration = 0;
	while (alive == 1) {
		iteration++;
		system("cls");

		//Write game field
		for (j = 0; j < YSIZE; j++) {
			for (i = 0; i < XSIZE; i++) {
				if (map[i][j] == SNAKE)
					putchar('X');
				else if (map[i][j] == FOOD)
					putchar('O');
				else
					putchar(' ');
			}
			putchar('|');
			putchar('\n');
		}
		for (i = 0; i < XSIZE; i++)
			putchar('-');
		
		//Preset controls for testing
		switch (iteration) {
			case 2: {
				new_dir = LEFT;
				break;
			}
			case 4: {
				new_dir = DOWN;
				break;
			}
			case 7: {
				new_dir = UP;
				break;
			}
			case 9: {
				new_dir = LEFT;
				break;
			}
			case 11: {
				new_dir = DOWN;
				break;
			}
		}
		
		//180 degree turn prevented
		if ((direction*new_dir) < 0)
			direction = new_dir;

		//300 ms "tick"
		Sleep(300);
		timer_callback();

		/*if (start) {
			//A startot interrupt kezelő fv-ben állítjuk, vagy egy feltételvizsgálat egy menürendszerben
			//Paramétereket beállítjuk
			alive = 1;
			start = 0;
		}
		//Megy a játék
		while (alive) {

		}*/
	}

	//End of game
	system("cls");
	printf("Game Over!");
	getchar();

	//---------------------------------------
	//				End of test
	//---------------------------------------

	return 0;
}