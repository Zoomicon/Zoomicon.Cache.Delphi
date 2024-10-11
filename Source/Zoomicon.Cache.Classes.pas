//Project: Zoomicon.Cache (https://github.com/Zoomicon/Zoomicon.Cache.Delphi)
//Author: George Birbilis (http://Zoomicon.com)
//Description: Content caching implementations

unit Zoomicon.Cache.Classes;

interface
  uses
    Zoomicon.Cache.Models, //for IContentCache
    System.Classes, //for TStream
    System.Generics.Collections; //for TDictionary

  //Note: The Caches use case-sensitive keys.
  //      If a filepath or a URL is passed as key, one may opt to convert it to
  //      uppercase or lowercase before passing to any of the functions

  type

    TBaseCache = class(TInterfacedObject, IContentCache)
      protected
        function GetKeyHash(const Key: String): String; virtual;

      public
        function HasContent(const Key: String): Boolean; virtual; abstract;
        function GetContent(const Key: String): TStream; virtual; abstract;
        procedure PutContent(const Key: String; const Content: TStream); virtual; abstract;
    end;

    TMemoryCache = class(TBaseCache)
      protected
        FContentDictionary: TDictionary<String, TStream>;
      public
        constructor Create(const ACapacity: NativeInt = 0); virtual;
        destructor Destroy(); override;

        { IContentCache }
        function HasContent(const Key: String): Boolean; override;
        function GetContent(const Key: String): TStream; override;
        procedure PutContent(const Key: String; const Content: TStream); override;
    end;

    TFileCache = class(TBaseCache, IFileCache) //note: if we didn't inherit from TBaseCache which impements IContentCache, we'd need to be declaring that interface too as implemented, even though IContentCache is ancestor of IFileCache: needed in Delphi if we want to pass as the ancestor interface
      public
        { IContentCache }
        function HasContent(const Key: String): Boolean; override;
        function GetContent(const Key: String): TStream; override;
        procedure PutContent(const Key: String; const Content: TStream); override;
        { IFileCache }
        function GetFilepath(const Key: String): String; virtual;
    end;

    TZCompressedFileCache = class(TFileCache) //no need to implement IContentCache and IFileCache, declared at ancestors
      { IContentCache }
      function GetContent(const Key: String): TStream; override;
      procedure PutContent(const Key: String; const Content: TStream); override;
    end;

implementation
  uses
    System.Hash, //for THashSHA2
    System.SysUtils, //for ENotImplemented, FileExists
    System.IOUtils, //for TPath, TDirectory
    System.ZLib; //for TZCompressionStream, TZDecompressionStream

{$region 'TBaseCache'}

function TBaseCache.GetKeyHash(const Key: String): String;
begin
  result := THashSHA2.GetHashString(Key, THashSHA2.TSHA2Version.SHA512).ToUpperInvariant; //See https://en.wikipedia.org/wiki/SHA-2 //ends up calling THash.DigestAsString which returns lowercase hex chars A-F, so converting to uppercase (using Locale invariant conversion)
end;

{$endregion}

{$region 'TMemoryCache'}

constructor TMemoryCache.Create(const ACapacity: NativeInt = 0);
begin
  inherited Create;
  FContentDictionary := TDictionary<string, TStream>.Create(ACapacity);
end;

destructor TMemoryCache.Destroy;
begin
  FreeAndNil(FContentDictionary);
  inherited Destroy;
end;

function TMemoryCache.HasContent(const Key: string): Boolean;
begin
  result := FContentDictionary.ContainsKey(Key);
end;

function TMemoryCache.GetContent(const Key: string): TStream;
begin
  FContentDictionary.TryGetValue(Key, result); //will return Default(TStream), that is nil, if not found
end;

procedure TMemoryCache.PutContent(const Key: string; const Content: TStream);
begin
  var CacheStream := TMemoryStream.Create();
  try
    CacheStream.LoadFromStream(Content); //copies from start of stream
  except
    FreeAndNil(CacheStream);
  end;
  FContentDictionary.AddOrSetValue(Key, CacheStream)
end;

{$endregion}

{$region 'TFileCache'}

function TFileCache.GetFilepath(const Key: string): string;
begin
  result := TPath.Combine(TPath.Combine(TPath.GetCachePath, UnitName), GetKeyHash(Key));

  //Using UnitName in the path too since it also contains Zoomicon in it (in some platforms there's no per-app cache folder)
  //TODO: must change to use application name or module name (if running in context of some host) in a cross-platform way, or allow caller to configure it

  //Using GetKeyHash (does SHA-512) to generate a unique HEX chars string from given Key (which could have contained illegal file chars, e.g. a URL)
end;

function TFileCache.HasContent(const Key: string): Boolean;
begin
  result := FileExists(GetFilepath(Key));
end;

function TFileCache.GetContent(const Key: string): TStream;
begin
  var Filepath := GetFilepath(Key);
  if FileExists(Filepath) then
    result := TFileStream.Create(Filepath, fmOpenRead {or fmShareDenyNone}) //TODO: fmShareDenyNote probably needed for Android
  else
    result := nil;
end;

procedure TFileCache.PutContent(const Key: string; const Content: TStream);
begin
  var Filepath := GetFilepath(Key);

  TDirectory.CreateDirectory(TPath.GetDirectoryName(Filepath)); //create any missing subdirectories

  var CacheFile := TFileStream.Create(Filepath, fmCreate or fmOpenWrite {or fmShareDenyNone}); //overwrite any existing file //TODO: fmShareDenyNote probably needed for Android
  try
    CacheFile.CopyFrom(Content); //copies from start of stream
  finally
    FreeAndNil(CacheFile); //this should flush any buffers and close any file handles
  end;
end;

{$endregion}

{$region 'TZCompressedFileCache'}

function TZCompressedFileCache.GetContent(const Key: string): TStream;
begin
  var ZCompressedContent := inherited GetContent(Key);
  if Assigned(ZCompressedContent) then
    result := TZDecompressionStream.Create(ZCompressedContent)
  else
    result := nil;
end;

procedure TZCompressedFileCache.PutContent(const Key: string; const Content: TStream);
begin
  var ZCompressedContent := TZCompressionStream.Create(Content);
  try
    inherited PutContent(Key, ZCompressedContent);
  finally
    FreeAndNil(ZCompressedContent);
  end;
end;

{$endregion}

end.

