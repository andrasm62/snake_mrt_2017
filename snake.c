#define xsize 90
#define ysize 30
#define snake 1
#define snake_head 2
#define snake_tail 3
#define food 4

enum {right = 0, up, left, down};

uint8_t map[ysize][xsize];
uint8_t lenght = 4;			//Hossz
uint8_t direction = up;		//Kígyó iránya
uint8_t x_position = 30;
uint8_t y_position = 30;
uint8_t level = 1;			//Sebesség
uint8_t food_eated = 0;		//Megevett kaja


void draw_pixel(uint8_t x, uint8_t y, uint8_t value){}

void timer_callback(){
	switch(direction){
		case right: {
			x_position++;
			if(map[y_position][x_position] == valami) {do_valami()}
			break;
		}
		case up: {
			y_position++;
			if(map[y_position][x_position] == valami) {do_valami()}
			break;
		}
		case left: {
			x_position--;
			if(map[y_position][x_position] == valami) {do_valami()}
			break;
		}
		case down:{
			y_position--;
			if(map[y_position][x_position] == valami) {do_valami()}
			break;
		}
		default: return;
	}
	
	
	
}

int main(){

	unit8_t alive = 1;			//Játék megy-e?
	uint8_t i, j, k;			//ciklusváltozók
	
	
	init_pheriperals();
	start_timer();
	
	//Initialise map, snake and food
	for(i = 0; i < ysize; i++){
		for(j = 0; j < xsize; j++){
			map[i][j] = 0;
		}
	}
	map[30][30] = snake_head;
	map[29][30] = snake;
	map[28][30] = snake;
	map[27][30] = snake_tail;
	map[35][60] = food;
	
	while(1){
		
		if(start){
			//A startot interrupt kezelő fv-ben állítjuk, vagy egy feltételvizsgálat egy menürendszerben
			//Paramétereket beállítjuk
			alive = 1;
			start = 0;
		}
		//Megy a játék
		while(alive){
			
		}
		
		
		
	}
	return 0;	
}