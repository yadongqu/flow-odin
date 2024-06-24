package flow
import "base:intrinsics"
import "core:fmt"
import "core:math/linalg"
import "core:thread"
import "core:time"
prefix_table := [?]string{
	"White",
	"Red",
	"Green",
	"Blue",
	"Octarine",
	"Black",
}
print_mutex := b64(false)
did_acquire :: proc(m: ^b64) -> (acquired: bool) {
    res, ok := intrinsics.atomic_compare_exchange_strong(m, false, true)
    return ok && res == false
}

task_proc :: proc(t: thread.Task) {
    index := t.user_index % len(prefix_table)
    for iteration in 1..=5 {
        for !did_acquire(&print_mutex) { thread.yield() } // Allow one thread to print at a time.

        fmt.printf("Worker Task %d is on iteration %d\n", t.user_index, iteration)
        fmt.printf("`%s`: iteration %d\n", prefix_table[index], iteration)


        print_mutex = false

        time.sleep(1 * time.Millisecond)
    }
}

Film :: struct {
    width : int,
    height: int,
    data : [dynamic]linalg.Vector3f32
}

render :: proc() {
    N :: 16
    pool : thread.Pool
    thread.pool_init(&pool, allocator=context.allocator, thread_count = N)
    defer thread.pool_destroy(&pool)
    width := 512
    height := 512
    film := Film {
        width,
        height,
        make([dynamic]linalg.Vector3f32, width * height)
    }
    tile_size := 64

    Tile :: struct {
        x: int,
        y: int,
        width: int,
        height: int,
    }

    tiles := make([dynamic]Tile)
    for x := 0; x < film.width; x += tile_size {
        for y := 0; y < film.height; y += tile_size {
            final_width := min(film.width - x, tile_size)
            final_height := min(film.height - y, tile_size)
            append_elem(&tiles, Tile {
                x,y, final_width, final_height
            })
        }
    }

    for i in 0..<len(tiles) {
        thread.pool_add_task(&pool, allocator=context.allocator, procedure=task_proc, data=&tiles[i], user_index=i)
    }

    thread.pool_start(&pool)
    thread.pool_finish(&pool)

}


main :: proc() {
    render()
    // N :: 3
    // pool: thread.Pool
    // thread.pool_init(&pool, allocator=context.allocator, thread_count=N)
    // defer thread.pool_destroy(&pool)
    // for i in 0..<30 {
    //     // be mindful of the allocator used for tasks. The allocator needs to be thread safe, or be owned by the task for exclusive use 
    //     thread.pool_add_task(&pool, allocator=context.allocator, procedure=task_proc, data=nil, user_index=i)
    // }

    // thread.pool_start(&pool)

    // // {
    // //     // Wait a moment before we cancel a thread
    // //     time.sleep(5 * time.Millisecond)

    // //     // Allow one thread to print at a time.
    // //     for !did_acquire(&print_mutex) { thread.yield() }

    // //     thread.terminate(pool.threads[N - 1], 0)
    // //     fmt.println("Canceled last thread")
    // //     print_mutex = false
    // // }
    // thread.pool_finish(&pool)
}