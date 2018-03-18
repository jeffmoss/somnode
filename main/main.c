/* HTTP GET Example using plain POSIX sockets

   This example code is in the Public Domain (or CC0 licensed, at your option.)

   Unless required by applicable law or agreed to in writing, this
   software is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
   CONDITIONS OF ANY KIND, either express or implied.
*/
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_event_loop.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "driver/i2s.h"

#include "lwip/err.h"
#include "lwip/sockets.h"
#include "lwip/sys.h"
#include "lwip/netdb.h"
#include "lwip/dns.h"

#if defined(INT_DATA) || defined(INT_EVENT) || defined(INT_CLICK)
#define INT_USED
#endif

#include "lis3dh.h"

// user task stack depth for ESP32
#define TASK_STACK_DEPTH 2048

/* -- use following constants to define the lis3dh mode ----------- */

// #define SPI_USED     // SPI interface is used, otherwise I2C
#define FIFO_MODE    // multiple sample read mode
// #define INT_DATA     // data interrupts used (data ready and FIFO status)
// #define INT_EVENT    // inertial event interrupts used (wake-up, free fall or 6D/4D orientation)
// #define INT_CLICK    // click detection interrupts used

// SPI interface definitions for ESP32
#define SPI_BUS       HSPI_HOST
#define SPI_SCK_GPIO  16
#define SPI_MOSI_GPIO 17
#define SPI_MISO_GPIO 18
#define SPI_CS_GPIO   19

// I2C interface defintions for ESP32
#define I2C_BUS       0
#define I2C_SCL_PIN   14
#define I2C_SDA_PIN   13
#define I2C_FREQ      I2C_FREQ_100K

// interrupt GPIOs defintions for ESP32
#define INT1_PIN      5
#define INT2_PIN      4

/* The examples use simple WiFi configuration that you can set via
   'make menuconfig'.

   If you'd rather not, just change the below entries to strings with
   the config you want - ie #define EXAMPLE_WIFI_SSID "mywifissid"
*/
#define EXAMPLE_WIFI_SSID CONFIG_WIFI_SSID
#define EXAMPLE_WIFI_PASS CONFIG_WIFI_PASSWORD

/* FreeRTOS event group to signal when we are connected & ready to make a request */
static EventGroupHandle_t wifi_event_group;

/* The event group allows multiple bits for each event,
   but we only care about one event - are we connected
   to the AP with an IP? */
const int CONNECTED_BIT = BIT0;

/* Constants that aren't configurable in menuconfig */
#define WEB_SERVER "heavyobjects.com"
#define WEB_PORT 80
#define WEB_URL "/"

static const char *TAG = "somnode";

static const char *REQUEST = "GET " WEB_URL " HTTP/1.1\n"
    "Host: "WEB_SERVER"\n"
    "User-Agent: esp-idf/1.0 esp32\n"
    "\n";

static lis3dh_sensor_t* sensor;

static const int i2s_num = 0; // i2s port number

const int sample_rate = 44100;

static const i2s_config_t i2s_config = {
  .mode = I2S_MODE_MASTER | I2S_MODE_RX,
  .sample_rate = 44100,
  .bits_per_sample = I2S_BITS_PER_SAMPLE_32BIT, // 16
  .channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT,
  .communication_format = I2S_COMM_FORMAT_I2S_MSB, // I2S_COMM_FORMAT_I2S | I2S_COMM_FORMAT_I2S_MSB
  .intr_alloc_flags = 0, // default interrupt priority
  .dma_buf_count = 32,
  .dma_buf_len = 32 * 2,
  .use_apll = false
};

static const i2s_pin_config_t pin_config = {
  .bck_io_num = GPIO_NUM_27,
  .ws_io_num = GPIO_NUM_25,
  .data_out_num = I2S_PIN_NO_CHANGE,
  .data_in_num = GPIO_NUM_26
};

static esp_err_t event_handler(void *ctx, system_event_t *event)
{
    switch(event->event_id) {
    case SYSTEM_EVENT_STA_START:
        esp_wifi_connect();
        break;
    case SYSTEM_EVENT_STA_GOT_IP:
        xEventGroupSetBits(wifi_event_group, CONNECTED_BIT);
        break;
    case SYSTEM_EVENT_STA_DISCONNECTED:
        /* This is a workaround as ESP32 WiFi libs don't currently
           auto-reassociate. */
        esp_wifi_connect();
        xEventGroupClearBits(wifi_event_group, CONNECTED_BIT);
        break;
    default:
        break;
    }
    return ESP_OK;
}

/**
 * Common function used to get sensor data.
 */
void read_data ()
{
    #ifdef FIFO_MODE

    lis3dh_float_data_fifo_t fifo;

    if (lis3dh_new_data (sensor))
    {
        uint8_t num = lis3dh_get_float_data_fifo (sensor, fifo);

        ESP_LOGD(TAG, "%.3f LIS3DH num=%d\n", (double)sdk_system_get_time()*1e-3, num);

        for (int i=0; i < num; i++)
            // max. full scale is +-16 g and best resolution is 1 mg, i.e. 5 digits
	    ESP_LOGD(TAG, "%.3f LIS3DH (xyz)[g] ax=%+7.3f ay=%+7.3f az=%+7.3f\n",
                   (double)sdk_system_get_time()*1e-3, 
                   fifo[i].ax, fifo[i].ay, fifo[i].az);
    }

    #else

    lis3dh_float_data_t  data;

    if (lis3dh_new_data (sensor) &&
        lis3dh_get_float_data (sensor, &data))
        // max. full scale is +-16 g and best resolution is 1 mg, i.e. 5 digits
        ESP_LOGD(TAG, "%.3f LIS3DH (xyz)[g] ax=%+7.3f ay=%+7.3f az=%+7.3f\n",
		 (double)sdk_system_get_time()*1e-3, data.ax, data.ay, data.az);
        
    #endif // FIFO_MODE
}

static void initialise_wifi(void)
{
    tcpip_adapter_init();
    wifi_event_group = xEventGroupCreate();
    ESP_ERROR_CHECK( esp_event_loop_init(event_handler, NULL) );
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK( esp_wifi_init(&cfg) );
    ESP_ERROR_CHECK( esp_wifi_set_storage(WIFI_STORAGE_RAM) );
    wifi_config_t wifi_config = {
        .sta = {
            .ssid = EXAMPLE_WIFI_SSID,
            .password = EXAMPLE_WIFI_PASS,
        },
    };
    ESP_LOGI(TAG, "Setting WiFi configuration SSID %s...", wifi_config.sta.ssid);
    ESP_ERROR_CHECK( esp_wifi_set_mode(WIFI_MODE_STA) );
    ESP_ERROR_CHECK( esp_wifi_set_config(WIFI_IF_STA, &wifi_config) );
    ESP_ERROR_CHECK( esp_wifi_start() );
}

static void init_i2s()
{
    i2s_driver_install(i2s_num, &i2s_config, 0, NULL);   //install and start i2s driver

    i2s_set_pin(i2s_num, &pin_config);

    i2s_set_sample_rates(i2s_num, sample_rate); //set sample rates

    ESP_LOGI(TAG, "Configured microphone.");
}

static void microphone_task(void *pvParameters)
{
    uint16_t buf_len = 1024;
    char *buf = calloc(buf_len, sizeof(char));

    init_i2s();

    // i2s_driver_uninstall(i2s_num);
    // ESP_LOGI(TAG, "Stopped microphone.");

    ESP_LOGI(TAG, "Reading mic\r\n");

    int cnt = 0;

    while (1)
    {
        // passive waiting until 1 second is over
        // vTaskDelay(100/portTICK_PERIOD_MS);

        char *buf_ptr_read = buf;

        // read whole block of samples
        int bytes_read = 0;
        while(bytes_read == 0) {
	    bytes_read = i2s_read_bytes(i2s_num, buf, buf_len, 0);
        }

	ESP_LOGI(TAG, "Read %d bytes", bytes_read);

	uint32_t samples_read = bytes_read / 2 / (I2S_BITS_PER_SAMPLE_32BIT / 8);

	ESP_LOGI(TAG, "Read %d samples (%d)", samples_read, buf_ptr_read[3]);

	cnt += samples_read;

	if(cnt >= sample_rate) {
	    cnt = 0;

	    ESP_LOGI(TAG, "Sample read complete");
	}
    }
}

static void periodic_accel_task(void *pvParameters)
{
    vTaskDelay (100/portTICK_PERIOD_MS);
    
    while (1)
    {
	ESP_LOGI(TAG, "Reading accel data\r\n");

        // read sensor data
        read_data ();

        // passive waiting until 1 second is over
        vTaskDelay(100/portTICK_PERIOD_MS);
    }
}

static void http_get_task(void *pvParameters)
{
    const struct addrinfo hints = {
        .ai_family = AF_INET,
        .ai_socktype = SOCK_STREAM,
    };
    struct addrinfo *res;
    struct in_addr *addr;
    int s, r;
    char recv_buf[64];

    while(1) {
        /* Wait for the callback to set the CONNECTED_BIT in the
           event group.
        */
        xEventGroupWaitBits(wifi_event_group, CONNECTED_BIT,
                            false, true, portMAX_DELAY);
        ESP_LOGI(TAG, "Connected to AP");

        int err = getaddrinfo(WEB_SERVER, "80", &hints, &res);

        if(err != 0 || res == NULL) {
            ESP_LOGE(TAG, "DNS lookup failed err=%d res=%p", err, res);
            vTaskDelay(1000 / portTICK_RATE_MS);
            continue;
        }

        /* Code to print the resolved IP.

           Note: inet_ntoa is non-reentrant, look at ipaddr_ntoa_r for "real" code */
        addr = &((struct sockaddr_in *)res->ai_addr)->sin_addr;
        ESP_LOGI(TAG, "DNS lookup succeeded. IP=%s", inet_ntoa(*addr));

        s = socket(res->ai_family, res->ai_socktype, 0);
        if(s < 0) {
            ESP_LOGE(TAG, "... Failed to allocate socket.");
            freeaddrinfo(res);
            vTaskDelay(1000 / portTICK_RATE_MS);
            continue;
        }
        ESP_LOGI(TAG, "... allocated socket\r\n");

        if(connect(s, res->ai_addr, res->ai_addrlen) != 0) {
            ESP_LOGE(TAG, "... socket connect failed errno=%d", errno);
            close(s);
            freeaddrinfo(res);
            vTaskDelay(4000 / portTICK_RATE_MS);
            continue;
        }

        ESP_LOGI(TAG, "... connected");
        freeaddrinfo(res);

        if (write(s, REQUEST, strlen(REQUEST)) < 0) {
            ESP_LOGE(TAG, "... socket send failed");
            close(s);
            vTaskDelay(4000 / portTICK_RATE_MS);
            continue;
        }
        ESP_LOGI(TAG, "... socket send success");

        /* Read HTTP response */
        do {
            bzero(recv_buf, sizeof(recv_buf));
            r = read(s, recv_buf, sizeof(recv_buf)-1);
            for(int i = 0; i < r; i++) {
                putchar(recv_buf[i]);
            }
        } while(r == (sizeof(recv_buf)-1));

        ESP_LOGI(TAG, "... done reading from socket. Last read return=%d errno=%d\r\n", r, errno);
        close(s);
        for(int countdown = 5; countdown >= 0; countdown--) {
            ESP_LOGI(TAG, "%d... ", countdown);
            vTaskDelay(1000 / portTICK_RATE_MS);
        }
        ESP_LOGI(TAG, "Starting again!");
    }
}

void app_main()
{
    ESP_LOGI(TAG, "START app_main\r\n");

    // Set UART Parameter.
    uart_set_baud(0, 115200);

    // Give the UART some time to settle
    vTaskDelay(1);

    nvs_flash_init();
    // initialise_wifi();

    // create a user task to fetch data from a webserver
    // xTaskCreate(&http_get_task, "http_get_task", TASK_STACK_DEPTH, NULL, 2, NULL);

    // create a user task to fetch data from the I2S microphone
    xTaskCreate(&microphone_task, "microphone_task", TASK_STACK_DEPTH, NULL, 6, NULL);

    // create a user task that fetches data from sensor periodically
    xTaskCreate(&periodic_accel_task, "periodic_accel_task", TASK_STACK_DEPTH, NULL, 5, NULL);

    ESP_LOGI(TAG, "FINISH app_main\r\n");
}
