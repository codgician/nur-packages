# This file was generated by nvfetcher, please do not modify it manually.
{ fetchgit, fetchurl, fetchFromGitHub, dockerTools }:
{
  aiursoft-tracer = {
    pname = "aiursoft-tracer";
    version = "9b12d878a0a2174cef634160c82094e20f61dbed";
    src = fetchgit {
      url = "https://gitlab.aiursoft.cn/aiursoft/tracer";
      rev = "9b12d878a0a2174cef634160c82094e20f61dbed";
      fetchSubmodules = false;
      deepClone = false;
      leaveDotGit = false;
      sha256 = "sha256-fOhToNCmh8yN6ZZzlLOuGaviy/WOAp3yq1M2KnHG0kQ=";
    };
    date = "2024-09-06";
  };
}
