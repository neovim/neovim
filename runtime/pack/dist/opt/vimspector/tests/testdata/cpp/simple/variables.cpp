#include <iostream>

int main() {
    std::cout << "Hello world!" << std::endl;
    int a = 1;
    ++a;
    int& b = a;
    ++a;
    std::cout << "a: " << a << " b: " << b << std::endl;
    return 0;
}
