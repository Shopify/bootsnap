#include "ruby.h"
#include <dirent.h>
#include <stdlib.h>

static VALUE bs_dirscanner_scan(int, VALUE*, VALUE);
void bs_dirscanner_scan_recursively(char*, char**, int);
int bs_dirscanner_is_prefix(const char *pre, const char *str);

static VALUE module, bootsnap_module;

void
Init_dirscanner(void)
{
  bootsnap_module = rb_define_module("Bootsnap");
  module = rb_define_module_under(bootsnap_module, "DirScanner");
  rb_define_module_function(module, "scan", bs_dirscanner_scan, -1);
}

static VALUE
bs_dirscanner_scan(int argc, VALUE* argv, VALUE self)
{
  VALUE path, opts; // arguments

  // helper variables
  char* c_path;
  VALUE excluded, result;
  char **exclusions;
  int num_of_excluded, str_len, i;

  rb_scan_args(argc, argv, "11", &path, &opts);
  
  // handle optional opts argument
  if(NIL_P(opts)) opts = rb_hash_new();

  // get :excluded from opts, set to empty array if not present  
  excluded = rb_funcall(opts, rb_intern("[]"), 1, ID2SYM(rb_intern("excluded")));
  if(NIL_P(excluded))
  {
    excluded = rb_ary_new();
  }

  // convert Ruby string to C string
  c_path = RSTRING_PTR(path);

  // save number of items in excluded array - this makes things easier later
  num_of_excluded = NUM2INT(rb_funcall(excluded, rb_intern("length"), 0));

  // convert array of Ruby string into array of C strings
  exclusions = malloc(num_of_excluded * sizeof(char*));
  for(i=0;i<num_of_excluded;i++)
  {
    result = rb_ary_entry(excluded, i);
    Check_Type(result, T_STRING);
    str_len = RSTRING_LEN(result);
    exclusions[i] = RSTRING_PTR(result);
  }

  // start recursive directory scanning
  bs_dirscanner_scan_recursively(c_path, exclusions, num_of_excluded);

  free(exclusions);

  return Qnil;
}

// assuming that base_path is an absolute path
void bs_dirscanner_scan_recursively(char *base_path, char **exclusions, int num_of_exclusions)
{
    char *path, *abspath, *formatted_str;
    struct dirent *dp;
    DIR *dir = opendir(base_path);
    VALUE to_yield;
    int i, should_skip = 0;

    // nothing to do if we are not in the directory
    if (!dir)
        return;

    while ((dp = readdir(dir)) != NULL)
    {
      // if a name starts with a dot, skip it
      // this is to mimic how Dir.glob works
      if(dp->d_name[0] == '.')
        continue;

      // create absolute path
      formatted_str = malloc(strlen(base_path) + strlen(dp->d_name) + 2);
      sprintf(formatted_str, "%s/%s", base_path, dp->d_name);

      // check if it's not one of excluded paths
      should_skip = 0;
      for(i=0; i<num_of_exclusions; i++)
      {
        if(bs_dirscanner_is_prefix(exclusions[i], formatted_str))
        {
          should_skip = 1;
        }
      }
      if(should_skip > 0) continue;

      // if we are still executing, the path is good
      // yield it
      to_yield = rb_str_new_cstr(formatted_str);
      rb_yield_values(1, to_yield);

      // prepare for recursion
      path = malloc(strlen(base_path) + 2 + strlen(dp->d_name) * sizeof(char));
      strcpy(path, base_path);
      strcat(path, "/");
      strcat(path, dp->d_name);

      // ... and call recursively
      bs_dirscanner_scan_recursively(path, exclusions, num_of_exclusions);

      free(path);
      free(formatted_str);
    }
    closedir(dir);
}

// checks if second argument starts with the first one
int bs_dirscanner_is_prefix(const char *prefix, const char *string)
{
    return strncmp(prefix, string, strlen(prefix)) == 0;
}