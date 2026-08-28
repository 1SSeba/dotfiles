// Hace que QtWebEngine (WebEngineView) funcione dentro de Quickshell, sin
// recompilar quickshell.
//
// Quickshell arranca la app con argc = 0 (src/launch/launch.cpp: `auto qArgC = 0;`),
// así que QCoreApplication::arguments() queda vacío y Chromium se mata con
//   FATAL: Argument list is empty, the program name is not passed to QCoreApplication.
// Encima nadie llama a QtWebEngineQuick::initialize(), que tiene que correr antes
// de que exista la QGuiApplication.
//
// Este shim se precarga con LD_PRELOAD y arregla las dos cosas:
//   1. Un constructor de librería (corre antes de main) llama a initialize().
//   2. Interpone el ctor de QGuiApplication para subir argc de 0 a 1, así
//      Chromium ve al menos el nombre del programa.
//
// Detalles que importan:
//
//   - LD_PRELOAD se queda puesto a propósito. Quickshell se re-ejecuta a sí mismo
//     (supervisor + shell), y si le sacamos la variable el proceso hijo arranca sin
//     shim y crashea igual que antes.
//
//   - Como la variable la heredan TODOS los procesos que lanza la shell, acá no se
//     linkea Qt: el constructor primero mira si el programa es quickshell y recién
//     ahí hace dlopen de QtWebEngineQuick. Un `bash` lanzado desde la shell mapea
//     estos 16 KB y nada más, en vez de arrastrar medio Qt.
//
//   - Exporta QS_WEBENGINE=1, que es lo que mira Social.qml para decidir si puede
//     instanciar un WebEngineView. Sin este shim la variable no existe y la QML
//     cae al modo "botón Abrir" en vez de crashear la shell entera.
//
// Rebuild: ./build.sh  (casi nunca hace falta: no linkea Qt, ver build.sh)

#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

extern char* program_invocation_short_name;

namespace {

bool isQuickshell() {
    const char* name = program_invocation_short_name;
    return name != nullptr && (strcmp(name, "quickshell") == 0 || strcmp(name, "qs") == 0);
}

__attribute__((constructor)) void qsWebEngineInit() {
    if (!isQuickshell()) return;

    // RTLD_GLOBAL porque después el plugin QML de QtWebEngine resuelve contra esto.
    void* lib = dlopen("libQt6WebEngineQuick.so.6", RTLD_NOW | RTLD_GLOBAL);
    if (lib == nullptr) return;

    auto initialize = reinterpret_cast<void (*)()>(dlsym(lib, "_ZN16QtWebEngineQuick10initializeEv"));
    if (initialize == nullptr) return;

    initialize();
    setenv("QS_WEBENGINE", "1", 1);
}

} // namespace

// Los dos ctors, porque cuál se usa depende del shell: con
// `//@ pragma UseQApplication` (el caso de ii/shell.qml) quickshell construye un
// QApplication, y si solo interponés el de QGuiApplication el argc sigue en 0 y
// Chromium se mata igual.

using Ctor = void (*)(void*, int&, char**, int);

namespace {
void fixArgc(int& argc, char** argv) {
    if (argc < 1 && argv != nullptr && argv[0] != nullptr) argc = 1;
}
} // namespace

extern "C" void _ZN15QGuiApplicationC1ERiPPci(void* self, int& argc, char** argv, int version) {
    static auto real = reinterpret_cast<Ctor>(dlsym(RTLD_NEXT, "_ZN15QGuiApplicationC1ERiPPci"));
    fixArgc(argc, argv);
    real(self, argc, argv, version);
}

extern "C" void _ZN12QApplicationC1ERiPPci(void* self, int& argc, char** argv, int version) {
    static auto real = reinterpret_cast<Ctor>(dlsym(RTLD_NEXT, "_ZN12QApplicationC1ERiPPci"));
    fixArgc(argc, argv);
    real(self, argc, argv, version);
}
