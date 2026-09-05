using System.Net;
using System.Net.Http.Headers;
using AcerControl.Service.Models;

namespace AcerControl.Service.Api;

public sealed class BearerTokenMiddleware(
    RequestDelegate next,
    ILogger<BearerTokenMiddleware> logger,
    IHostEnvironment environment)
{
    public async Task InvokeAsync(HttpContext context, ApiTokenProvider tokenProvider)
    {
        if (!context.Request.Path.StartsWithSegments("/api/v1"))
        {
            await next(context);
            return;
        }

        var remoteAddress = context.Connection.RemoteIpAddress;
        if ((remoteAddress is null && !environment.IsEnvironment("Testing")) ||
            (remoteAddress is not null && !IPAddress.IsLoopback(remoteAddress)))
        {
            await WriteErrorAsync(context, 403, "local_only", "The API accepts local requests only.");
            return;
        }

        if (context.Request.Headers.ContainsKey("Origin"))
        {
            await WriteErrorAsync(
                context,
                403,
                "browser_origin_rejected",
                "Browser-origin requests are not accepted.");
            return;
        }

        if (HttpMethods.IsPut(context.Request.Method) ||
            HttpMethods.IsPost(context.Request.Method))
        {
            if (context.Request.ContentType is null ||
                !context.Request.ContentType.StartsWith(
                    "application/json",
                    StringComparison.OrdinalIgnoreCase))
            {
                await WriteErrorAsync(
                    context,
                    415,
                    "json_required",
                    "Control requests require application/json.");
                return;
            }
        }

        try
        {
            if (!AuthenticationHeaderValue.TryParse(
                    context.Request.Headers.Authorization,
                    out var authorization) ||
                !string.Equals(
                    authorization.Scheme,
                    "Bearer",
                    StringComparison.OrdinalIgnoreCase) ||
                string.IsNullOrWhiteSpace(authorization.Parameter) ||
                !tokenProvider.IsValid(authorization.Parameter))
            {
                await WriteErrorAsync(
                    context,
                    401,
                    "unauthorized",
                    "A valid bearer token is required.");
                return;
            }
        }
        catch (Exception exception) when (
            exception is IOException or UnauthorizedAccessException)
        {
            logger.LogError(exception, "The API token could not be loaded.");
            await WriteErrorAsync(
                context,
                503,
                "token_unavailable",
                "The API token is unavailable.");
            return;
        }

        await next(context);
    }

    private static Task WriteErrorAsync(
        HttpContext context,
        int statusCode,
        string code,
        string message)
    {
        context.Response.StatusCode = statusCode;
        return context.Response.WriteAsJsonAsync(
            new ApiErrorResponse("error", new ApiError(code, message)));
    }
}