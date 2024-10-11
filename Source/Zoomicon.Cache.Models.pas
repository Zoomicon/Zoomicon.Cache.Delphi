//Project: Zoomicon.Cache (https://github.com/Zoomicon/Zoomicon.Cache.Delphi)
//Author: George Birbilis (http://Zoomicon.com)
//Description: Content caching models

unit Zoomicon.Cache.Models;

interface
  uses System.Classes; //for TStream

  type

    IContentCache = interface
      ['{0E920B3E-7362-4653-8F5C-866745C1204F}']
      function HasContent(const Key: string): Boolean;
      function GetContent(const Key: string): TStream;
      procedure PutContent(const Key: string; const Content: TStream);
    end;

    IFileCache = interface(IContentCache)
      ['{FB74770E-59F9-4FDD-AAFE-1ADE32B0A63E}']
      function GetFilepath(const Key: string): string;
    end;

implementation

end.
