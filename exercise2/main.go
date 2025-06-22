package main

import (
	"flag"
	"fmt"
	"github.com/ugol/canonical/exercise2/shredder/shredder"
	"os"
)

func main() {

	nFlag := flag.Int("n", 1, "Number of passes to overwrite the file")
	uFlag := flag.Bool("u", false, "Remove the file after shredding")
	zFlag := flag.Bool("z", false, "Add a final overwrite of all zeros")
	flag.Parse()

	args := flag.Args()
	if len(args) != 1 {
		fmt.Println("Usage: shredder [options] <file>")
		flag.PrintDefaults()
		os.Exit(1)
	}
	filePath := args[0]

	err := shredder.Shred(filePath, *nFlag, false)
	if err != nil {
		fmt.Printf("Error shredding file: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("File %s shredded with %d passes.\n", filePath, *nFlag)

	if *zFlag {
		fmt.Println("Overwriting with zeroes...")
		err = shredder.Shred(filePath, 1, true)
		if err != nil {
			fmt.Printf("Error performing zero overwrite: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("Final overwrite complete.")
	}

	if *uFlag {
		fmt.Println("Removing file after shredding...")
		err = os.Remove(filePath)
		if err != nil {
			fmt.Printf("Error removing file: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("File removed successfully.")
	}
}
