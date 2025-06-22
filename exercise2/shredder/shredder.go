package shredder

import (
	"crypto/rand"
	"errors"
	"os"
)

func Shred(path string, passes int, zero bool) error {
	info, err := os.Stat(path)
	if err != nil {
		return err
	}
	if info.IsDir() {
		return errors.New("shred: path is a directory, not a file")
	}
	size := info.Size()
	f, err := os.OpenFile(path, os.O_WRONLY, 0)
	if err != nil {
		return err
	}

	for i := 0; i < passes; i++ {

		buf := make([]byte, 4096)
		var written int64 = 0
		for written < size {
			if zero {
				for j := range buf {
					buf[j] = 0
				}
			} else {
				_, err := rand.Read(buf)
				if err != nil {
					_ = f.Close()
					return err
				}
			}

			toWrite := int64(len(buf))
			if size-written < toWrite {
				toWrite = size - written
			}
			n, err := f.Write(buf[:toWrite])
			if err != nil {
				_ = f.Close()
				return err
			}
			written += int64(n)
		}

		err = f.Sync()
		if err != nil {
			return err
		}
		err = f.Close()
		if err != nil {
			return err
		}
	}

	return nil
}
