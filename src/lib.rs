#![allow(non_snake_case)]
extern crate libcruby_sys;

use libcruby_sys::{
    Qfalse, Qtrue, Qnil,
    c_string, c_func, VALUE,
    NUM2U32,
    rb_check_type, T_STRING, T_FIXNUM, RSTRING_PTR, RSTRING_LEN,
    rb_define_module, rb_define_module_under, rb_define_class_under,
};

use std::ffi::CString;
use std::fs::File;
use std::slice;
use std::io::{Read, Error, ErrorKind};
use std::str;
use std::time;

macro_rules! c_str {
    ($x:expr) => (CString::new($x).unwrap().as_ptr());
}

static mut COMPILE_OPTION: u32 = 0;

extern "C" {
    pub fn rb_get_coverages() -> VALUE;
    pub static rb_eStandardError: VALUE;
    pub fn rb_define_module_function(module: VALUE, name: c_string, func: c_func, arity: isize);
}

#[no_mangle]
pub unsafe extern "C" fn Init_native() {
    let mod_bootsnap: VALUE = rb_define_module(c_str!("Bootsnap"));
    rb_define_class_under(mod_bootsnap, c_str!("Uncompilable"), rb_eStandardError);
    let mod_native: VALUE = rb_define_module_under(mod_bootsnap, c_str!("Native"));

    rb_define_module_function(
        mod_native, c_str!("coverage_running?"), bs_coverage_running as c_func, 0);
    rb_define_module_function(
        mod_native, c_str!("compile_option_crc32="), bs_compile_option_crc32_set as c_func, 1);
    rb_define_module_function(
        mod_native, c_str!("fetch"), bs_fetch as c_func, 3);
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

struct Mstr {
    rust: String,
    ruby: VALUE,
}

impl Mstr {
    unsafe fn new(rstring: VALUE) -> Mstr {
        Mstr { ruby: rstring, rust: rstring_to_string(rstring) }
    }
}

unsafe fn rstring_to_string(rstring: VALUE) -> String {
    let slice = slice::from_raw_parts(
        RSTRING_PTR(rstring) as *const u8,
        RSTRING_LEN(rstring) as usize
    );
    str::from_utf8(slice).unwrap().to_string()
}

#[no_mangle]
pub unsafe extern "C" fn bs_fetch(_: VALUE, path_v: VALUE, cache_path_v: VALUE, handler: VALUE) -> VALUE {
    rb_check_type(path_v, T_STRING);
    rb_check_type(cache_path_v, T_STRING);

    let path       = Mstr::new(path_v);
    let cache_path = Mstr::new(cache_path_v);

    println!("{} : {} : {:?}", path.rust, cache_path.rust, handler);

    match fetch(path, cache_path, handler) {
        Ok(value) => value,
        Err(err)  => libcruby_sys::rb_raise(rb_eStandardError, c_str!(format!("{}", err))),
    }
}

fn fetch(path: Mstr, cache_path: Mstr, handler: VALUE) -> Result<VALUE, std::io::Error> {
    let mut f_curr = File::open(path.rust)?;
    let stat = f_curr.metadata()?;

    let size  = stat.len() as usize;
    let mtime = stat.modified()?.duration_since(time::UNIX_EPOCH).unwrap().as_secs();

    if let Ok(f_cache) = File::open(cache_path.rust) {
        println!("neato")
    }

    // build cache key, test cache...

    let mut buf: Vec<u8> = vec![];
    let sz = f_curr.read_to_end(&mut buf)?;
    if sz != size {
        return Err(Error::new(ErrorKind::Other, "wrong size"));
    }

    // key->version        = current_version;
    // key->os_version     = current_os_version;
    // key->compile_option = current_compile_option_crc32;
    // key->ruby_revision  = current_ruby_revision;
    // key->size           = (uint64_t)statbuf.st_size;
    // key->mtime = (uint64_t)statbuf.st_mtime;

    // current_fd = open_current_file(path, &current_key, &errno_provenance);
    // if (current_fd < 0) goto fail_errno;

    unsafe { return Ok(Qnil); }
}
