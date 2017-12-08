#![allow(non_snake_case)]
extern crate libcruby_sys;

use libcruby_sys::{
    Qfalse, Qtrue, Qnil,
    c_string, c_func, VALUE,
    NUM2U32,
    rb_check_type, T_STRING, T_FIXNUM,
    rb_define_module, rb_define_module_under, rb_define_class_under,
};

use std::ffi::CString;

static mut COMPILE_OPTION: u32 = 0;

extern "C" {
    pub fn rb_get_coverages() -> VALUE;
    pub static rb_eStandardError: VALUE;
    pub fn rb_define_module_function(module: VALUE, name: c_string, func: c_func, arity: isize);
}

#[no_mangle]
pub extern "C" fn Init_native() {
    let bootsnap     = CString::new("Bootsnap").unwrap();
    let native       = CString::new("Native").unwrap();
    let uncompilable = CString::new("Uncompilable").unwrap();

    let mod_native: VALUE;
    unsafe {
        let mod_bootsnap: VALUE = rb_define_module(bootsnap.as_ptr());
        rb_define_class_under(mod_bootsnap, uncompilable.as_ptr(), rb_eStandardError);
        mod_native = rb_define_module_under(mod_bootsnap, native.as_ptr());
    }

    {
        let i = CString::new("coverage_running?").unwrap();
        let f = bs_coverage_running as c_func;
        unsafe {
            rb_define_module_function(mod_native, i.as_ptr(), f, 0);
        }
    }

    {
        let i = CString::new("compile_option_crc32=").unwrap();
        let f = bs_compile_option_crc32_set as c_func;
        unsafe {
            rb_define_module_function(mod_native, i.as_ptr(), f, 1);
        }
    }

    {
        let i = CString::new("fetch").unwrap();
        let f = bs_fetch as c_func;
        unsafe {
            rb_define_module_function(mod_native, i.as_ptr(), f, 3);
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn bs_coverage_running(_: VALUE) -> VALUE {
    if Qfalse == rb_get_coverages() {
        Qfalse
    } else {
        Qtrue
    }
}

#[no_mangle]
pub unsafe extern "C" fn bs_compile_option_crc32_set(_: VALUE, option: VALUE) -> VALUE {
    rb_check_type(option, T_FIXNUM);
    COMPILE_OPTION = NUM2U32(option);
    return Qnil;
}

#[no_mangle]
pub unsafe extern "C" fn bs_fetch(_: VALUE, path: VALUE, cache_path: VALUE, handler: VALUE) -> VALUE {
    rb_check_type(path, T_STRING);
    rb_check_type(cache_path, T_STRING);

    println!("{:?}", handler);
    return Qnil;
}
