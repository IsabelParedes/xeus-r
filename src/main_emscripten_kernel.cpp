/***************************************************************************
* Copyright (c) 2023, QuantStack
*                                                                          
* Distributed under the terms of the GNU General Public License v3.                 
*                                                                          
* The full license is in the file LICENSE, distributed with this software. 
****************************************************************************/

#include <iostream>
#include <memory>

#include <emscripten/bind.h>

#include <xeus/xembind.hpp>

#include "xeus-r/xinterpreter_wasm.hpp"

EMSCRIPTEN_BINDINGS(my_module)
{
    std::cout << "OOO xeus::export_core()" << std::endl;
    xeus::export_core();
    std::cout << "OOO get interpreter type" << std::endl;
    using interpreter_type = xeus_r::wasm_interpreter;
    std::cout << "OOO xeus::export_kernel<interpreter_type>()" << std::endl;
    xeus::export_kernel<interpreter_type>("xkernel");
    std::cout << "OOO done with that" << std::endl;
}