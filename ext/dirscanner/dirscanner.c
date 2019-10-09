#include "ruby.h"
#include <dirent.h>
#include <stdlib.h>

static VALUE bs_dirscanner_scan(VALUE, VALUE, VALUE);
void bs_dirscanner_scan_recursively(char*, char**, int);
int bs_dirscanner_is_prefix(const char *pre, const char *str);

static VALUE module, bootsnap_module;

void
Init_dirscanner(void)
{
  //bootsnap_module = rb_const_get(rb_cModule, rb_intern("Bootsnap"));
  bootsnap_module = rb_define_module("Bootsnap");
  module = rb_define_module_under(bootsnap_module, "DirScanner");
  rb_define_module_function(module, "scan", bs_dirscanner_scan, 2);
}

static VALUE
bs_dirscanner_scan(VALUE self, VALUE path, VALUE opts)
{
  char* c_path;
  VALUE excluded, result;
  char **exclusions;
  int num_of_excluded, str_len, i;

  excluded = rb_funcall(opts, rb_intern("[]"), 1, ID2SYM(rb_intern("excluded")));
  if(NIL_P(excluded))
  {
    excluded = rb_ary_new();
  }

  c_path = RSTRING_PTR(path);

  num_of_excluded = NUM2INT(rb_funcall(excluded, rb_intern("length"), 0));
  exclusions = malloc(num_of_excluded * sizeof(char*));
  for(i=0;i<num_of_excluded;i++)
  {
    result = rb_ary_entry(excluded, i);
    Check_Type(result, T_STRING);
    str_len = RSTRING_LEN(result);
    exclusions[i] = RSTRING_PTR(result);
  }

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

    if (!dir)
        return;

    while ((dp = readdir(dir)) != NULL)
    {
      should_skip = 0;
      if (strcmp(dp->d_name, ".") == 0 || strcmp(dp->d_name, "..") == 0)
        continue;
      
      if(dp->d_name[0] == '.')
        continue;

      formatted_str = malloc(strlen(base_path) + strlen(dp->d_name) + 2);
      sprintf(formatted_str, "%s/%s", base_path, dp->d_name);

      for(i=0; i<num_of_exclusions; i++)
      {
        if(bs_dirscanner_is_prefix(exclusions[i], formatted_str))
        {
          should_skip = 1;
        }
      }
      if(should_skip > 0) continue;

      to_yield = rb_str_new_cstr(formatted_str);
      rb_yield_values(1, to_yield);

      // prepare for recursion
      path = malloc(strlen(base_path) + 2 + strlen(dp->d_name) * sizeof(char));
      strcpy(path, base_path);
      strcat(path, "/");
      strcat(path, dp->d_name);

      bs_dirscanner_scan_recursively(path, exclusions, num_of_exclusions);

      free(path);
      free(formatted_str);
    }
    closedir(dir);
}

int bs_dirscanner_is_prefix(const char *pre, const char *str)
{
    return strncmp(pre, str, strlen(pre)) == 0;
}