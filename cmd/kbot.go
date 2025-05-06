/*
Copyright © 2025 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/spf13/cobra"
	"gopkg.in/telebot.v3"
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
			log.Printf("Отримано команду /start від %s", ctx.Sender().Username)
			replyMessage := fmt.Sprintf("Привіт, %s! Я простий бот на Telebot. Напиши /help, щоб побачити список команд.", ctx.Sender().FirstName)
			return ctx.Send(replyMessage)
		})
		kbot.Handle("/hello", func(ctx telebot.Context) error {
			senderUsername := ctx.Sender().Username
			senderFirstName := ctx.Sender().FirstName
			log.Printf("Отримано команду /hello від %s (%s)", senderFirstName, senderUsername)
			replyMessage := fmt.Sprintf("Привіт, %s! Радий тебе бачити. Як справи?", senderFirstName)
			return ctx.Send(replyMessage)
		})
		kbot.Handle("/help", func(ctx telebot.Context) error {
			log.Printf("Отримано команду /help від %s", ctx.Sender().Username)

			var helpMessage strings.Builder // Використовуємо strings.Builder для ефективної конкатенації рядків
			helpMessage.WriteString("Ось список доступних команд:\n\n")

			for command, description := range commands {
				helpMessage.WriteString(fmt.Sprintf("/%s - %s\n", command, description))
			}

			// Надсилаємо сформоване повідомлення
			return ctx.Send(helpMessage.String())
		})
		kbot.Handle("/version", func(ctx telebot.Context) error {
			log.Printf("Отримано команду /version від %s", ctx.Sender().Username)
			var versionRepy strings.Builder
			versionRepy.WriteString(fmt.Sprintf("Поточна версія програми kbot: %s", appVersion))

			return ctx.Send(versionRepy.String())
		})
		kbot.Handle("/ping", func(ctx telebot.Context) error {
			log.Printf("Отримано команду /ping від %s", ctx.Sender().Username)
			if response, ok := commands["ping"]; ok {
				return ctx.Send(response)
			}
			return ctx.Send("Щось пішло не так з командою ping.")
		})
		kbot.Handle(telebot.OnText, func(ctx telebot.Context) error {
			log.Printf("Отримано текст '%s' від %s", ctx.Text(), ctx.Sender().Username)
			return ctx.Send(fmt.Sprintf("Ви написали: '%s'. Спробуйте /help для списку команд.", ctx.Text()))
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
