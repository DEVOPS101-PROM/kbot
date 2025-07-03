/*
Copyright © 2025 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/spf13/cobra"
	"gopkg.in/telebot.v3"
	"github.dev/DEVOPS101-PROM/kbot/internal/telemetry"
)

var (
	// TekeToken bot
	TekeToken = os.Getenv("TELE_TOKEN")
)

// kbotCmd represents the kbot command
var kbotCmd = &cobra.Command{
	Use:     "kbot",
	Aliases: []string{"start"},
	Short:   "A brief description of your command",
	Long: `A longer description that spans multiple lines and likely contains examples
and usage of using your command. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("kbot %s started", appVersion)
		
		// Initialize telemetry
		ctx := context.Background()
		if err := telemetry.InitTelemetry(ctx, "kbot", appVersion); err != nil {
			log.Printf("Failed to initialize telemetry: %v", err)
		}
		defer telemetry.Shutdown(ctx)
		
		commands := map[string]string{
			"help":    "Ця команда виводить перелік команд які приймає Kbot",
			"version": "Показує версію програми Kbot",
			"hello":   "поверне вітальне значення",
			"ping":    "pong",
			// Додайте сюди інші команди за потреби
		}

		kbot, err := telebot.NewBot(telebot.Settings{
			URL:    "",
			Token:  TekeToken,
			Poller: &telebot.LongPoller{Timeout: 10 * time.Second},
		})

		if err != nil {
			log.Fatalf("Please check TELE_TOKEN env variable. %s", err)
			return
		}
		kbot.Handle("/start", func(ctx telebot.Context) error {
			startTime := time.Now()
			username := ctx.Sender().Username
			if username == "" {
				username = "unknown"
			}
			
			// Record command with telemetry
			telemetryCtx := context.Background()
			telemetry.RecordCommand(telemetryCtx, "start", username)
			
			log.Printf("Отримано команду /start від %s", username)
			replyMessage := fmt.Sprintf("Привіт, %s! Я простий бот на Telebot. Напиши /help, щоб побачити список команд.", ctx.Sender().FirstName)
			
			err := ctx.Send(replyMessage)
			telemetry.RecordResponseTime("start", time.Since(startTime))
			return err
		})
		kbot.Handle("/hello", func(ctx telebot.Context) error {
			startTime := time.Now()
			senderUsername := ctx.Sender().Username
			if senderUsername == "" {
				senderUsername = "unknown"
			}
			senderFirstName := ctx.Sender().FirstName
			
			// Record command with telemetry
			telemetryCtx := context.Background()
			telemetry.RecordCommand(telemetryCtx, "hello", senderUsername)
			
			log.Printf("Отримано команду /hello від %s (%s)", senderFirstName, senderUsername)
			replyMessage := fmt.Sprintf("Привіт, %s! Радий тебе бачити. Як справи?", senderFirstName)
			
			err := ctx.Send(replyMessage)
			telemetry.RecordResponseTime("hello", time.Since(startTime))
			return err
		})
		kbot.Handle("/help", func(ctx telebot.Context) error {
			startTime := time.Now()
			username := ctx.Sender().Username
			if username == "" {
				username = "unknown"
			}
			
			// Record command with telemetry
			telemetryCtx := context.Background()
			telemetry.RecordCommand(telemetryCtx, "help", username)
			
			log.Printf("Отримано команду /help від %s", username)

			var helpMessage strings.Builder // Використовуємо strings.Builder для ефективної конкатенації рядків
			helpMessage.WriteString("Ось список доступних команд:\n\n")

			for command, description := range commands {
				helpMessage.WriteString(fmt.Sprintf("/%s - %s\n", command, description))
			}

			// Надсилаємо сформоване повідомлення
			err := ctx.Send(helpMessage.String())
			telemetry.RecordResponseTime("help", time.Since(startTime))
			return err
		})
		kbot.Handle("/version", func(ctx telebot.Context) error {
			startTime := time.Now()
			username := ctx.Sender().Username
			if username == "" {
				username = "unknown"
			}
			
			// Record command with telemetry
			telemetryCtx := context.Background()
			telemetry.RecordCommand(telemetryCtx, "version", username)
			
			log.Printf("Отримано команду /version від %s", username)
			var versionRepy strings.Builder
			versionRepy.WriteString(fmt.Sprintf("Поточна версія програми kbot: %s", appVersion))

			err := ctx.Send(versionRepy.String())
			telemetry.RecordResponseTime("version", time.Since(startTime))
			return err
		})
		kbot.Handle("/ping", func(ctx telebot.Context) error {
			startTime := time.Now()
			username := ctx.Sender().Username
			if username == "" {
				username = "unknown"
			}
			
			// Record command with telemetry
			telemetryCtx := context.Background()
			telemetry.RecordCommand(telemetryCtx, "ping", username)
			
			log.Printf("Отримано команду /ping від %s", username)
			if response, ok := commands["ping"]; ok {
				err := ctx.Send(response)
				telemetry.RecordResponseTime("ping", time.Since(startTime))
				return err
			}
			err := ctx.Send("Щось пішло не так з командою ping.")
			telemetry.RecordResponseTime("ping", time.Since(startTime))
			return err
		})
		kbot.Handle(telebot.OnText, func(ctx telebot.Context) error {
			startTime := time.Now()
			username := ctx.Sender().Username
			if username == "" {
				username = "unknown"
			}
			
			// Record command with telemetry
			telemetryCtx := context.Background()
			telemetry.RecordCommand(telemetryCtx, "text", username)
			
			log.Printf("Отримано текст '%s' від %s", ctx.Text(), username)
			err := ctx.Send(fmt.Sprintf("Ви написали: '%s'. Спробуйте /help для списку команд.", ctx.Text()))
			telemetry.RecordResponseTime("text", time.Since(startTime))
			return err
		})

		kbot.Start()
	},
}

func init() {
	rootCmd.AddCommand(kbotCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// kbotCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// kbotCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}
