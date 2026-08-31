require "http"
require "json"
require "uuid"

class ImageHost
  MaxUploadBytes = 10 * 1024 * 1024
  ImageDirectory = "images"
  AllowedImageTypes = {
    ".gif"  => "image/gif",
    ".jpeg" => "image/jpeg",
    ".jpg"  => "image/jpeg",
    ".png"  => "image/png",
    ".webp" => "image/webp",
  }

  class UploadFailure
    getter status : HTTP::Status
    getter message : String

    def initialize(@status : HTTP::Status, @message : String)
    end
  end

  def initialize
    Dir.mkdir_p(ImageDirectory)
  end

  def handle(context : HTTP::Server::Context)
    request = context.request

    case request.method
    when "GET"
      handleGet(context)
    when "POST"
      handlePost(context)
    else
      respondError(context, HTTP::Status::METHOD_NOT_ALLOWED, "Method not allowed.")
    end
  rescue error
    respondError(context, HTTP::Status::INTERNAL_SERVER_ERROR, "The server could not process that request.")
  end

  private def handleGet(context : HTTP::Server::Context)
    path = context.request.path

    if path == "/"
      renderHome(context)
      return
    end

    if path.starts_with?("/images/")
      renderImage(context, path[8..])
      return
    end

    respondError(context, HTTP::Status::NOT_FOUND, "Not found.")
  end

  private def handlePost(context : HTTP::Server::Context)
    if context.request.path != "/upload"
      respondError(context, HTTP::Status::NOT_FOUND, "Not found.")
      return
    end

    contentLength = context.request.headers["Content-Length"]?.try(&.to_i?)
    if contentLength && contentLength > MaxUploadBytes + 16_384
      respondError(context, HTTP::Status::PAYLOAD_TOO_LARGE, "Images must be 10 MB or smaller.")
      return
    end

    uploadResult = saveUpload(context.request)
    case uploadResult
    when String
      publicUrl = "#{requestOrigin(context.request)}/images/#{uploadResult}"
      context.response.content_type = "application/json"
      context.response.print({Url: publicUrl}.to_json)
    when UploadFailure
      respondError(context, uploadResult.status, uploadResult.message)
    end
  end

  private def saveUpload(request : HTTP::Request) : String | UploadFailure
    contentType = request.headers["Content-Type"]?
    unless contentType && contentType.includes?("multipart/form-data")
      return UploadFailure.new(HTTP::Status::BAD_REQUEST, "Send a multipart form containing a file field.")
    end

    uploadResult : String | UploadFailure | Nil = nil

    HTTP::FormData.parse(request) do |part|
      next unless part.name == "file" && part.filename && uploadResult.nil?

      extension = File.extname(part.filename.not_nil!).downcase
      mimeType = AllowedImageTypes[extension]?
      unless mimeType
        uploadResult = UploadFailure.new(HTTP::Status::UNSUPPORTED_MEDIA_TYPE, "Only PNG, JPG, GIF, and WEBP images are allowed.")
        next
      end

      storedName = "#{UUID.random}#{extension}"
      storedPath = File.join(ImageDirectory, storedName)

      begin
        bytesWritten = copyWithinLimit(part.body, storedPath)
        if bytesWritten > MaxUploadBytes
          File.delete(storedPath) if File.exists?(storedPath)
          uploadResult = UploadFailure.new(HTTP::Status::PAYLOAD_TOO_LARGE, "Images must be 10 MB or smaller.")
        else
          uploadResult = storedName
        end
      rescue error
        File.delete(storedPath) if File.exists?(storedPath)
        raise error
      end
    end

    uploadResult || UploadFailure.new(HTTP::Status::BAD_REQUEST, "Choose an image before uploading.")
  end

  private def copyWithinLimit(source : IO, destinationPath : String) : Int64
    buffer = Bytes.new(8_192)
    bytesWritten = 0_i64

    File.open(destinationPath, "wb") do |destination|
      loop do
        bytesRead = source.read(buffer)
        break if bytesRead == 0

        bytesWritten += bytesRead
        if bytesWritten > MaxUploadBytes
          break
        end

        destination.write(buffer[0, bytesRead])
      end
    end

    bytesWritten
  end

  private def renderImage(context : HTTP::Server::Context, imageName : String)
    unless imageName == File.basename(imageName)
      respondError(context, HTTP::Status::NOT_FOUND, "Not found.")
      return
    end

    extension = File.extname(imageName).downcase
    mimeType = AllowedImageTypes[extension]?
    imagePath = File.join(ImageDirectory, imageName)

    unless mimeType && File.file?(imagePath)
      respondError(context, HTTP::Status::NOT_FOUND, "Not found.")
      return
    end

    context.response.content_type = mimeType
    context.response.headers["Cache-Control"] = "public, max-age=604800, immutable"
    File.open(imagePath, "rb") do |imageFile|
      IO.copy(imageFile, context.response)
    end
  end

  private def renderHome(context : HTTP::Server::Context)
    context.response.content_type = "text/html; charset=utf-8"
    context.response.print(homePage)
  end

  private def respondError(context : HTTP::Server::Context, status : HTTP::Status, message : String)
    context.response.status = status
    context.response.content_type = "application/json"
    context.response.print({Error: message}.to_json)
  end

  private def requestOrigin(request : HTTP::Request) : String
    forwardedProto = request.headers["X-Forwarded-Proto"]? || "http"
    host = request.headers["Host"]? || "localhost:3000"
    "#{forwardedProto}://#{host}"
  end

  private def homePage : String
    <<-HTML
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Utsuu Image Host</title>
        <style>
          :root
          {
            color-scheme: dark;
            font-family: Inter, ui-sans-serif, system-ui, sans-serif;
          }

          body
          {
            display: grid;
            min-height: 100vh;
            margin: 0;
            place-items: center;
            background: #0d1117;
            color: #f0f6fc;
          }

          main
          {
            width: min(90vw, 520px);
            padding: 2.5rem;
            border: 1px solid #30363d;
            border-radius: 18px;
            background: #161b22;
            box-shadow: 0 24px 80px #0008;
          }

          h1
          {
            margin-top: 0;
          }

          p
          {
            color: #8b949e;
          }

          input, button
          {
            box-sizing: border-box;
            width: 100%;
            margin-top: 1rem;
            padding: .8rem 1rem;
            border-radius: 8px;
            font: inherit;
          }

          input
          {
            border: 1px solid #30363d;
            background: #0d1117;
          }

          button
          {
            border: 0;
            background: #238636;
            color: white;
            cursor: pointer;
          }

          button:disabled
          {
            cursor: wait;
            opacity: .65;
          }

          #Result
          {
            display: none;
            overflow-wrap: anywhere;
            margin-top: 1.25rem;
            color: #58a6ff;
          }
        </style>
      </head>
      <body>
        <main>
          <h1>Utsuu Image Host</h1>
          <p>Upload a PNG, JPG, GIF, or WEBP image up to 10 MB.</p>
          <form id="UploadForm">
            <input id="ImageFile" name="file" type="file" accept="image/png,image/jpeg,image/gif,image/webp" required>
            <button id="UploadButton" type="submit">Upload image</button>
          </form>
          <a id="Result" target="_blank" rel="noreferrer"></a>
        </main>
        <script>
          const UploadForm = document.getElementById("UploadForm");
          const UploadButton = document.getElementById("UploadButton");
          const Result = document.getElementById("Result");

          UploadForm.addEventListener("submit", async (Event) =>
          {
            Event.preventDefault();
            UploadButton.disabled = true;
            Result.style.display = "none";

            try
            {
              const Response = await fetch("/upload",
              {
                method: "POST",
                body: new FormData(UploadForm)
              });
              const Payload = await Response.json();

              if (!Response.ok)
              {
                throw new Error(Payload.Error || "Upload failed.");
              }

              Result.href = Payload.Url;
              Result.textContent = Payload.Url;
              Result.style.display = "block";
            }
            catch (Error)
            {
              alert(Error.message);
            }
            finally
            {
              UploadButton.disabled = false;
            }
          });
        </script>
      </body>
    </html>
    HTML
  end
end

application = ImageHost.new
server = HTTP::Server.new do |context|
  application.handle(context)
end

address = server.bind_tcp("0.0.0.0", 3000)
puts "Utsuu Image Host is listening on http://#{address}"
server.listen
