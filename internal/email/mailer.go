package email

import (
	"context"
	"fmt"
	"log"
	"net/smtp"
	"strings"
)

type Mailer interface {
	Send(ctx context.Context, to, subject, body string) error
}

type Config struct {
	From         string
	ResendAPIKey string
	SMTPHost     string
	SMTPPort     string
	SMTPUser     string
	SMTPPass     string
	AppName      string
	Production   bool
}

// NewMailer picks Resend API → SMTP → console log (dev only).
func NewMailer(cfg Config) Mailer {
	from := cfg.From
	if from == "" {
		from = "Gains <onboarding@resend.dev>"
	}
	if key := strings.TrimSpace(cfg.ResendAPIKey); key != "" {
		return newResendMailer(key, from)
	}
	if strings.TrimSpace(cfg.SMTPHost) != "" {
		return &smtpMailer{cfg: cfg}
	}
	if cfg.Production {
		log.Printf("[email] WARNING: no RESEND_API_KEY or SMTP_HOST — auth emails will NOT be delivered")
	}
	return LogMailer{From: from, AppName: cfg.AppName}
}

type LogMailer struct {
	From    string
	AppName string
}

func (m LogMailer) Send(_ context.Context, to, subject, body string) error {
	from := m.From
	if from == "" {
		from = "noreply@gains.local"
	}
	app := m.AppName
	if app == "" {
		app = "Gains"
	}
	log.Printf("[email] %s → %s\nSubject: %s\n%s", from, to, subject, body)
	return nil
}

type smtpMailer struct {
	cfg Config
}

func (m *smtpMailer) Send(_ context.Context, to, subject, body string) error {
	from := m.cfg.From
	if from == "" {
		from = m.cfg.SMTPUser
	}
	addr := fmt.Sprintf("%s:%s", m.cfg.SMTPHost, m.cfg.SMTPPort)
	msg := []byte(fmt.Sprintf("From: %s\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n%s",
		from, to, subject, body))
	var auth smtp.Auth
	if m.cfg.SMTPUser != "" {
		auth = smtp.PlainAuth("", m.cfg.SMTPUser, m.cfg.SMTPPass, m.cfg.SMTPHost)
	}
	return smtp.SendMail(addr, auth, from, []string{to}, msg)
}

func VerificationBody(appName, code string) (subject, body string) {
	if appName == "" {
		appName = "Gains"
	}
	subject = fmt.Sprintf("Verify your %s email", appName)
	body = fmt.Sprintf(`Hi,

Your %s verification code is:

%s

Enter this code in the app. It expires in 24 hours.

If you did not create an account, ignore this email.
`, appName, code)
	return subject, body
}

func ResetPasswordBody(appName, code string) (subject, body string) {
	if appName == "" {
		appName = "Gains"
	}
	subject = fmt.Sprintf("Reset your %s password", appName)
	body = fmt.Sprintf(`Hi,

Your %s password reset code is:

%s

Enter this code in the app. It expires in 1 hour.

If you did not request a reset, ignore this email.
`, appName, code)
	return subject, body
}
