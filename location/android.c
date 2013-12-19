/*  RetroArch - A frontend for libretro.
 *  Copyright (C) 2010-2013 - Hans-Kristian Arntzen
 *  Copyright (C) 2011-2013 - Daniel De Matteis
 * 
 *  RetroArch is free software: you can redistribute it and/or modify it under the terms
 *  of the GNU General Public License as published by the Free Software Found-
 *  ation, either version 3 of the License, or (at your option) any later version.
 *
 *  RetroArch is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 *  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *  PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with RetroArch.
 *  If not, see <http://www.gnu.org/licenses/>.
 */

#include "../driver.h"
#include "../android/native/jni/jni_macros.h"

typedef struct android_location
{
   jmethodID onLocationInit;
   jmethodID onLocationFree;
   jmethodID onLocationStart;
   jmethodID onLocationStop;
   jmethodID onLocationSetInterval;
   jmethodID onLocationGetLongitude;
   jmethodID onLocationGetLatitude;
} androidlocation_t;

static void *android_location_init(void)
{
   JNIEnv *env;
   jclass class;

   struct android_app *android_app = (struct android_app*)g_android;
   androidlocation_t *androidlocation = (androidlocation_t*)calloc(1, sizeof(androidlocation_t));
   if (!androidlocation)
      return NULL;

   env = jni_thread_getenv();
   if (!env)
      goto dealloc;

   GET_OBJECT_CLASS(env, class, android_app->activity->clazz);
   if (class == NULL)
      goto dealloc;

   GET_METHOD_ID(env, androidlocation->onLocationInit, class, "onLocationInit", "(II)V");
   if (!androidlocation->onLocationInit)
      goto dealloc;

   GET_METHOD_ID(env, androidlocation->onLocationFree, class, "onLocationFree", "()V");
   if (!androidlocation->onLocationFree)
      goto dealloc;

   GET_METHOD_ID(env, androidlocation->onLocationStart, class, "onLocationStart", "()V");
   if (!androidlocation->onLocationStart)
      goto dealloc;

   GET_METHOD_ID(env, androidlocation->onLocationStop, class, "onLocationStop", "()V");
   if (!androidlocation->onLocationStop)
      goto dealloc;

   GET_METHOD_ID(env, androidlocation->onLocationGetLatitude, class, "onLocationGetLatitude", "()J");
   if (!androidlocation->onLocationGetLatitude)
      goto dealloc;

   GET_METHOD_ID(env, androidlocation->onLocationGetLongitude, class, "onLocationGetLongitude", "()J");
   if (!androidlocation->onLocationGetLongitude)
      goto dealloc;

   GET_METHOD_ID(env, androidlocation->onLocationGetLongitude, class, "onLocationSetInterval", "(II)V");
   if (!androidlocation->onLocationSetInterval)
      goto dealloc;

   CALL_VOID_METHOD(env, android_app->activity->clazz, androidlocation->onLocationInit);

   return androidlocation;

dealloc:
   free(androidlocation);
   return NULL;
}

static void android_location_free(void *data)
{
   struct android_app *android_app = (struct android_app*)g_android;
   androidlocation_t *androidlocation = (androidlocation_t*)data;
   JNIEnv *env = jni_thread_getenv();
   if (!env)
      return;

   CALL_VOID_METHOD(env, android_app->activity->clazz, androidlocation->onLocationFree);

   free(androidlocation);
}

static bool android_location_start(void *data)
{
   struct android_app *android_app = (struct android_app*)g_android;
   androidlocation_t *androidlocation = (androidlocation_t*)data;
   JNIEnv *env = jni_thread_getenv();
   if (!env)
      return false;

   CALL_VOID_METHOD(env, android_app->activity->clazz, androidlocation->onLocationStart);

   return true;
}

static void android_location_stop(void *data)
{
   struct android_app *android_app = (struct android_app*)g_android;
   androidlocation_t *androidlocation = (androidlocation_t*)data;
   JNIEnv *env = jni_thread_getenv();
   if (!env)
      return;

   CALL_VOID_METHOD(env, android_app->activity->clazz, androidlocation->onLocationStop);
}

static double android_location_get_latitude(void *data)
{
   struct android_app *android_app = (struct android_app*)g_android;
   androidlocation_t *androidlocation = (androidlocation_t*)data;
   JNIEnv *env = jni_thread_getenv();
   if (!env)
      return 0.0;

   jdouble latitude;
   CALL_BOOLEAN_METHOD(env, latitude, android_app->activity->clazz, androidlocation->onLocationGetLatitude);
   return latitude;
}

static double android_location_get_longitude(void *data)
{
   struct android_app *android_app = (struct android_app*)g_android;
   androidlocation_t *androidlocation = (androidlocation_t*)data;
   JNIEnv *env = jni_thread_getenv();
   if (!env)
      return 0.0;

   jdouble longitude;
   CALL_BOOLEAN_METHOD(env, longitude, android_app->activity->clazz, androidlocation->onLocationGetLongitude);
   return longitude;
}

static void android_location_set_interval(void *data, unsigned interval_ms, unsigned interval_distance)
{
   struct android_app *android_app = (struct android_app*)g_android;
   androidlocation_t *androidlocation = (androidlocation_t*)data;
   JNIEnv *env = jni_thread_getenv();
   if (!env)
      return;

   CALL_VOID_METHOD_PARAM(env, android_app->activity->clazz, androidlocation->onLocationSetInterval, interval_ms, interval_distance);
}

const location_driver_t location_android = {
   android_location_init,
   android_location_free,
   android_location_start,
   android_location_stop,
   android_location_get_longitude,
   android_location_get_latitude,
   android_location_set_interval,
   "android",
};
