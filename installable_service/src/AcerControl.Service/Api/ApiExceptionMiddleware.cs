using AcerControl.Service.Models;

namespace AcerControl.Service.Api;

public sealed class ApiExceptionMiddleware(
    RequestDelegate next,
    ILogger<ApiExceptionMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
        {
        }
        catch (Exception exception)
        {
            var (status, code, message, applied, persisted) = exception switch
            {
                ArgumentException => (
                    400,
                    "invalid_request",
                    exception.Message,
                    (bool?)null,
                    (bool?)null),
                FirmwareUnavailableException => (
                    503,
                    "firmware_unavailable",
                    exception.Message,
                    null,
                    null),
                SettingsPersistenceException persistence => (
                    500,
                    "persistence_failed",
                    persistence.Message,
                    persistence.Applied,
                    persistence.Persisted),
                FirmwareOperationException => (
                    500,
                    "firmware_operation_failed",
                    exception.Message,
                    null,
                    null),
                _ => (
                    500,
                    "internal_error",
                    "The service could not complete the request.",
                    null,
                    null)
            };

            logger.LogError(exception, "API request {Method} {Path} failed.",
                context.Request.Method,
                context.Request.Path);
            if (!context.Response.HasStarted)
            {
                context.Response.StatusCode = status;
                await context.Response.WriteAsJsonAsync(
                    new ApiErrorResponse(
                        "error",
                        new ApiError(code, message),
                        applied,
                        persisted));
            }
        }
    }
}