# 1. Clean up previous failed build attempts
make clean
make distclean

# 2. Re-configure. 
# If you are on an Intel Mac, use darwin64-x86_64-cc.
# If you are on Apple Silicon but targeting x86_64, use the same.
./Configure darwin64-x86_64-cc no-shared --prefix=/usr/local/openssl-3.x

# 3. Build with verbose output to catch path errors
# Using -j4 to speed it up, but 1 if you want to see exactly where it fails.
make -j4

# 4. (Optional) If it still fails, manually check if the symbol exists in your libcrypto
# This helps verify if the library actually contains what the linker is looking for
nm -gU libcrypto.a | grep FMT_istext
