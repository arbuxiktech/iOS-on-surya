/*
 * sweettouch: synthetic touch and buttons over SSH, for testing without hands on the phone.
 *   sweettouch [--size WxH] tap X Y        one finger in display points (default 375x812)
 *   sweettouch [--size WxH] swipe X1 Y1 X2 Y2 [MS]  drag, default 300 ms
 *   sweettouch home | lock                 Home (menu) / Power (lock) button press
 * Events go into the HID event system (IOHIDEventSystemClientDispatchEvent) like a digitizer's, with the
 * entitlement com.apple.private.hid.client.event-dispatch (touch.entitlements). iOS 16 arm64 and iOS 18 arm64e builds.
 */
#include <CoreFoundation/CoreFoundation.h>
#include <mach/mach_time.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef);
extern void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef, IOHIDEventRef);
extern IOHIDEventRef IOHIDEventCreateDigitizerEvent(CFAllocatorRef, uint64_t ts, uint32_t transducer, uint32_t index,
    uint32_t identity, uint32_t eventMask, uint32_t buttonMask, double x, double y, double z, double pressure,
    double twist, bool range, bool touch, uint32_t options);
extern IOHIDEventRef IOHIDEventCreateDigitizerFingerEvent(CFAllocatorRef, uint64_t ts, uint32_t index, uint32_t identity,
    uint32_t eventMask, double x, double y, double z, double pressure, double twist, bool range, bool touch,
    uint32_t options);
extern IOHIDEventRef IOHIDEventCreateKeyboardEvent(CFAllocatorRef, uint64_t ts, uint32_t page, uint32_t usage,
    bool down, uint32_t flags);
extern void IOHIDEventAppendEvent(IOHIDEventRef parent, IOHIDEventRef child, uint32_t options);
extern void IOHIDEventSetIntegerValue(IOHIDEventRef, uint32_t field, int64_t value);
extern void IOHIDEventSetSenderID(IOHIDEventRef, uint64_t);

static double g_width = 375.0;
static double g_height = 812.0;
#define kIOHIDDigitizerTransducerTypeHand 3
#define kIOHIDDigitizerEventRange 0x1
#define kIOHIDDigitizerEventTouch 0x2
#define kIOHIDDigitizerEventPosition 0x4
#define kIOHIDEventFieldDigitizerIsDisplayIntegrated 0xb0019
#define SENDER 0x8000000817319372ULL            /* any fixed id: events are attributed to this "digitizer" */

static IOHIDEventSystemClientRef cli;

static void finger(double x, double y, bool touch, uint32_t mask)
{
	uint64_t t = mach_absolute_time();
	IOHIDEventRef hand = IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault, t, kIOHIDDigitizerTransducerTypeHand, 0, 0,
	    mask, 0, 0, 0, 0, 0, 0, touch, touch, 0);
	IOHIDEventSetIntegerValue(hand, kIOHIDEventFieldDigitizerIsDisplayIntegrated, 1);
	IOHIDEventRef f = IOHIDEventCreateDigitizerFingerEvent(kCFAllocatorDefault, t, 1, 2, mask, x / g_width, y / g_height, 0,
	    touch ? 1.0 : 0, 0, touch, touch, 0);
	IOHIDEventAppendEvent(hand, f, 0);
	IOHIDEventSetSenderID(hand, SENDER);
	IOHIDEventSystemClientDispatchEvent(cli, hand);
	CFRelease(f);
	CFRelease(hand);
}

static void button(uint32_t page, uint32_t usage)
{
	for (int down = 1; down >= 0; down--) {
		IOHIDEventRef e = IOHIDEventCreateKeyboardEvent(kCFAllocatorDefault, mach_absolute_time(), page, usage, down, 0);
		IOHIDEventSetSenderID(e, SENDER);
		IOHIDEventSystemClientDispatchEvent(cli, e);
		CFRelease(e);
		usleep(80000);
	}
}

static int
parse_size(const char *s)
{
	if (!s || !*s)
		return 0;
	char *end = NULL;
	long w = strtol(s, &end, 10);
	if (end == s || (*end != 'x' && *end != 'X') || w < 1 || w > 16384)
		return 0;
	const char *hstart = end + 1;
	long h = strtol(hstart, &end, 10);
	if (end == hstart || *end || h < 1 || h > 16384)
		return 0;
	g_width = (double)w;
	g_height = (double)h;
	return 1;
}

static void
usage(const char *name)
{
	fprintf(stderr, "usage: %s [--size WxH] tap X Y | swipe X1 Y1 X2 Y2 [MS] | home | lock\n", name);
	fprintf(stderr, "       coordinates are display points; default size is 375x812, Surya ADT default is 360x800\n");
}

int main(int argc, char **argv)
{
	int arg = 1;
	if (arg < argc && !strcmp(argv[arg], "--size")) {
		if (arg + 1 >= argc || !parse_size(argv[arg + 1])) {
			usage(argv[0]);
			return 2;
		}
		arg += 2;
	}
	cli = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
	if (!cli) {
		fprintf(stderr, "sweettouch: no HID event system client\n");
		return 1;
	}
	if (argc - arg == 3 && !strcmp(argv[arg], "tap")) {
		double x = atof(argv[arg + 1]), y = atof(argv[arg + 2]);
		finger(x, y, true, kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch);
		usleep(60000);
		finger(x, y, false, kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch);
	} else if ((argc - arg == 5 || argc - arg == 6) && !strcmp(argv[arg], "swipe")) {
		double x1 = atof(argv[arg + 1]), y1 = atof(argv[arg + 2]), x2 = atof(argv[arg + 3]), y2 = atof(argv[arg + 4]);
		int ms = argc - arg == 6 ? atoi(argv[arg + 5]) : 300, steps = ms / 8 > 2 ? ms / 8 : 2;
		finger(x1, y1, true, kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch);
		for (int i = 1; i <= steps; i++) {
			usleep(8000);
			finger(x1 + (x2 - x1) * i / steps, y1 + (y2 - y1) * i / steps, true, kIOHIDDigitizerEventPosition);
		}
		finger(x2, y2, false, kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch);
	} else if (argc - arg == 1 && !strcmp(argv[arg], "home")) {
		button(0x0c, 0x40);     /* consumer page, menu */
	} else if (argc - arg == 1 && !strcmp(argv[arg], "lock")) {
		button(0x0c, 0x30);     /* consumer page, power */
	} else {
		usage(argv[0]);
		return 2;
	}
	usleep(50000);
	return 0;
}
