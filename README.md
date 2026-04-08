# VGStackTrace

A lightweight, thread-safe stack trace tracking library for Delphi. Main feature of this library is that it is **platform independent** and allows to retrieve crude stack traces for all platforms. This is achieved by logging entry to all important functions and than retrieving this information when exception is raised.

`VGStackTrace` provides a simple way to track method execution paths across multiple threads in Delphi applications. It integrates seamlessly with the standard Delphi exception handling mechanism, ensuring that when an error occurs, you have a clear picture of the call stack that led to it.

## Features

- **Platform independent:** Allows to retrieve approximate stack traces for all platforms.
- **Thread-Safe:** Implemented to safely manage stack data across multiple threads.
- **RTL Integration:** Automatically hooks into `Exception.GetExceptionStackInfoProc` to provide stack traces for all exceptions.
- **Low Overhead:** Employs a fixed-size circular buffer (10 frames by default) per thread to keep memory usage predictable and minimal.
- **Automatic Lifecycle:** Initializes itself automatically upon inclusion and cleans up gracefully when the application terminates.
- **Self-Cleaning:** Automatically prunes data for inactive threads to prevent memory growth in long-running services.

## Installation

Simply add `VGStackTrace.pas` to your project and include it in your project's `uses` clause.

```pascal
program MyProject;

uses
  VGStackTrace,
  Vcl.Forms,
  MainUnit in 'MainUnit.pas' {MainForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
```

## Usage

### Recording Method Entry

To populate the stack trace, call `TVGStackTrace.EnterMethod` at the beginning of your methods:

```pascal
procedure TMyClass.DoSomething;
begin
  TVGStackTrace.EnterMethod('TMyClass.DoSomething');
  
  // Your code here...
end;
```

If you already have logging code in you application it is the best to integrate call to `TVGStackTrace.EnterMethod` into existing logging code.

### Retrieving the Stack Trace

The stack trace is automatically included in Delphi exceptions, just read `Exception.StackTrace` property. If you need to retrieve it manually for logging or debugging:

```pascal
begin
  WriteLn(TVGStackTrace.GetStackTrace); // returns stack trace for current thread
end;
```

## How it Works

`VGStackTrace` maintains a global `TObjectDictionary` mapping Thread IDs to circular buffers. When `EnterMethod` is called, it records the method name and the current timestamp. If an exception is raised, the Delphi RTL calls the hooks registered by `VGStackTrace` to retrieve the recorded call sequence for the current thread.

## Requirements

- Delphi (work with modern RAD Studio versions supporting Generics and `TThreadID`).

## License

This project is licensed under the **Mozilla Public License 2.0 (MPL 2.0)**. See the [LICENSE](LICENSE) file for details.
