package telemetry

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
	"go.opentelemetry.io/otel/trace"
)

var (
	// Prometheus metrics
	telegramCommandsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "telegram_commands_total",
			Help: "Total number of Telegram commands received",
		},
		[]string{"command", "user"},
	)

	telegramMessagesTotal = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "telegram_messages_total",
			Help: "Total number of Telegram messages received",
		},
	)

	telegramResponseTime = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "telegram_response_time_seconds",
			Help:    "Time taken to respond to Telegram commands",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"command"},
	)

	// OpenTelemetry tracer
	tracer trace.Tracer
)

func init() {
	// Register Prometheus metrics
	prometheus.MustRegister(telegramCommandsTotal)
	prometheus.MustRegister(telegramMessagesTotal)
	prometheus.MustRegister(telegramResponseTime)
}

// InitTelemetry initializes OpenTelemetry and Prometheus metrics
func InitTelemetry(ctx context.Context, serviceName, serviceVersion string) error {
	// Create resource
	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName(serviceName),
			semconv.ServiceVersion(serviceVersion),
		),
	)
	if err != nil {
		return fmt.Errorf("failed to create resource: %w", err)
	}

	// Initialize trace exporter
	traceExporter, err := otlptracehttp.New(ctx,
		otlptracehttp.WithEndpoint("http://localhost:4318"),
		otlptracehttp.WithInsecure(),
	)
	if err != nil {
		return fmt.Errorf("failed to create trace exporter: %w", err)
	}

	// Create trace provider
	traceProvider := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(traceExporter),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(traceProvider)

	// Set global propagator
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	// Initialize tracer
	tracer = otel.Tracer(serviceName)

	// Start Prometheus metrics server
	go func() {
		http.Handle("/metrics", promhttp.Handler())
		log.Printf("Starting Prometheus metrics server on :8080")
		if err := http.ListenAndServe(":8080", nil); err != nil {
			log.Printf("Failed to start metrics server: %v", err)
		}
	}()

	return nil
}

// RecordCommand records a Telegram command with tracing and metrics
func RecordCommand(ctx context.Context, command, username string) {
	// Create span for command processing
	ctx, span := tracer.Start(ctx, "telegram.command",
		trace.WithAttributes(
			semconv.HTTPMethodKey.String("POST"),
			semconv.HTTPRouteKey.String("/"+command),
		),
	)
	defer span.End()

	// Record Prometheus metrics
	telegramCommandsTotal.WithLabelValues(command, username).Inc()
	telegramMessagesTotal.Inc()

	// Add trace ID to span
	span.SetAttributes(
		semconv.HTTPStatusCode(200),
		semconv.HTTPRouteKey.String("/"+command),
	)
}

// RecordResponseTime records response time for a command
func RecordResponseTime(command string, duration time.Duration) {
	telegramResponseTime.WithLabelValues(command).Observe(duration.Seconds())
}

// GetTracer returns the global tracer
func GetTracer() trace.Tracer {
	return tracer
}

// Shutdown gracefully shuts down telemetry
func Shutdown(ctx context.Context) error {
	if tp, ok := otel.GetTracerProvider().(*sdktrace.TracerProvider); ok {
		if err := tp.Shutdown(ctx); err != nil {
			return fmt.Errorf("failed to shutdown tracer provider: %w", err)
		}
	}
	return nil
} 