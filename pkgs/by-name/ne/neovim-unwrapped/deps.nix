# Zig dependencies for neovim build system
# Complete dependency tree including transitive dependencies
{
  lib,
  linkFarm,
  fetchurl,
  fetchgit,
  runCommandLocal,
  zig_0_15,
}:

let
  unpackZigArtifact =
    {
      name,
      artifact,
    }:
    runCommandLocal name
      {
        nativeBuildInputs = [ zig_0_15 ];
      }
      ''
        hash="$(zig fetch --global-cache-dir "$TMPDIR" ${artifact})"
        mv "$TMPDIR/p/$hash" "$out"
        chmod 755 "$out"
      '';

  fetchZig =
    {
      name,
      url,
      hash,
    }:
    let
      artifact = fetchurl { inherit url hash; };
    in
    unpackZigArtifact { inherit name artifact; };

  fetchGitZig =
    {
      name,
      url,
      hash,
    }:
    let
      parts = lib.splitString "#" url;
      url_base = builtins.elemAt parts 0;
      url_without_query = builtins.elemAt (lib.splitString "?" url_base) 0;
      rev_base = builtins.elemAt parts 1;
      rev =
        if builtins.match "^[a-fA-F0-9]{40}$" rev_base != null then
          rev_base
        else
          "refs/heads/${rev_base}";
      artifact = fetchgit {
        url = lib.removePrefix "git+" url_without_query;
        inherit rev hash;
        sparseCheckout = [ ];
        fetchLFS = false;
        deepClone = false;
        leaveDotGit = false;
      };
    in
    unpackZigArtifact { inherit name artifact; };

  baseDeps = [
  {
    name = "zlua-0.1.0-hGRpC5c9BQAfU5bkkFfLV9B4a7Prw8N7JPIFAZBbRCkq";
    path = fetchGitZig {
      name = "zlua";
      url = "git+https://github.com/natecraddock/ziglua#a4d08d97795c312e63a0f09d456f7c6d280610b4";
      hash = "sha256-0JZkt3phNjlQF8OYXjQU3yBl1bWGO40d3+G6PjHuulg=";
    };
  }
  {
    name = "N-V-__8AAMnaAwCEutreuREG3QayBVEZqUTDQFY1Nsrv2OIt";
    path = fetchZig {
      name = "lpeg";
      url = "https://github.com/neovim/deps/raw/d495ee6f79e7962a53ad79670cb92488abe0b9b4/opt/lpeg-1.1.0.tar.gz";
      hash = "sha256-SxVdZ9IkbB/6ete8RmweqJm7xA/vAlfMnAPOy67UNSo=";
    };
  }
  {
    name = "N-V-__8AAMlNDwCY07jUoMiq3iORXdZy0uFWKiHsy8MaDBJA";
    path = fetchGitZig {
      name = "luv";
      url = "git+https://github.com/luvit/luv?ref=1.51.0-1#4c9fbc6cf6f3338bb0e0426710cf885ee557b540";
      hash = "sha256-vQfr0TwhkvRDJwZnxDD/53yCzyDouzQimTnwj4drs/c=";
    };
  }
  {
    name = "N-V-__8AADi-AwDnVoXwDCQvv2wcYOmN0bJLqZ44J3lwoQY2";
    path = fetchZig {
      name = "lua_compat53";
      url = "https://github.com/lunarmodules/lua-compat-5.3/archive/v0.13.tar.gz";
      hash = "sha256-9dww57H9qFbuTTkr5FdkLB8MJZJkqbm/vLaAMCzoj8I=";
    };
  }
  {
    name = "tree_sitter-0.26.0-Tw2sR_CLCwCTIP3h9KuZFjNhKGvn3SM3-IbuFKEqI0Yz";
    path = fetchGitZig {
      name = "treesitter";
      url = "git+https://github.com/tree-sitter/tree-sitter#f6d17fdb040636d84548e5da96f06c4c8d72eefd";
      hash = "sha256-+wbmlhhVbisSOPRCp3Cf4s7P+Dzn6jU00IHkmy8mERQ=";
    };
  }
  {
    name = "libuv-1.51.0-htqqv6liAADxBLIBCZT-qUh_3nRRwtNYsOFQOUmrd_sx";
    path = fetchGitZig {
      name = "libuv";
      url = "git+https://github.com/allyourcodebase/libuv#a2dfd385bd2a00d6d290fda85a40a55a9d6cffc5";
      hash = "sha256-9GSJS4PSMMfbJZlMSq65dCZ191i5PyDc4u+1/SSUkVc=";
    };
  }
  {
    name = "libiconv-1.18.0-p9sJwWnqAACzVYeWgXB5r5lOQ74XwTPlptixV0JPRO28";
    path = fetchGitZig {
      name = "libiconv";
      url = "git+https://github.com/allyourcodebase/libiconv#9def4c8a1743380e85bcedb80f2c15b455e236f3";
      hash = "sha256-CrLQ8fwQUtQmJJBvz6TPr4HxJFq+bhXHXsSDY0jYkjI=";
    };
  }
  {
    name = "N-V-__8AAGevEQCHAkCozca5AIdN9DFc3Luf3g3r2AcbyOrm";
    path = fetchZig {
      name = "lua_dev_deps";
      url = "https://github.com/neovim/deps/raw/06ef2b58b0876f8de1a3f5a710473dcd7afff251/opt/lua-dev-deps.tar.gz";
      hash = "sha256-Sfg5nkUxAwZKI8ZVNPJm8wZ82nFrZQLwFr+v7tV5k1Q=";
    };
  }
  {
    name = "N-V-__8AANxPSABzw3WBTSH_YkwaGAfrK6PBqAMqQedkDDim";
    path = fetchGitZig {
      name = "treesitter_c";
      url = "git+https://github.com/tree-sitter/tree-sitter-c?ref=v0.24.1#7fa1be1b694b6e763686793d97da01f36a0e5c12";
      hash = "sha256-gmzbdwvrKSo6C1fqTJFGxy8x0+T+vUTswm7F5sojzKc=";
    };
  }
  {
    name = "N-V-__8AABcZUwBZelO8MiLRwuLD1Wk34qHHbXtS4UW3Khys";
    path = fetchGitZig {
      name = "treesitter_markdown";
      url = "git+https://github.com/tree-sitter-grammars/tree-sitter-markdown?ref=v0.5.1#2dfd57f547f06ca5631a80f601e129d73fc8e9f0";
      hash = "sha256-IYqh6JT74deu1UU4Nyls9Eg88BvQeYEta2UXZAbuZek=";
    };
  }
  {
    name = "N-V-__8AAEF5CABqSL9zqc03aQsT6Nni54ZCcL98pnuDL2D3";
    path = fetchGitZig {
      name = "treesitter_lua";
      url = "git+https://github.com/tree-sitter-grammars/tree-sitter-lua?ref=v0.4.0#4569d1c361129e71a205b94a05e158bd71b1709f";
      hash = "sha256-VQJEW06GdgEA1L1GJW+Gbdktq2Sx72FRUtokSI5gUCA=";
    };
  }
  {
    name = "N-V-__8AAMArVAB4uo2wg2XRs8HBviQ4Pq366cC_iRolX4Vc";
    path = fetchGitZig {
      name = "treesitter_vim";
      url = "git+https://github.com/tree-sitter-grammars/tree-sitter-vim?ref=v0.7.0#3dd4747082d1b717b8978211c06ef7b6cd16125b";
      hash = "sha256-HOf35dd+zcpXHxFuWjJ6ju/5UZzALe0fUPPuAWXUIHM=";
    };
  }
  {
    name = "N-V-__8AAI4YCgD7OqxCEAmz2RqT_ohl6eA4F0fGMtLIe7nb";
    path = fetchGitZig {
      name = "treesitter_vimdoc";
      url = "git+https://github.com/neovim/tree-sitter-vimdoc?ref=v4.0.0#9f6191a98702edc1084245abd5523279d4b681fb";
      hash = "sha256-vAKX9Mx+ZYz7c2dWv01GOJN6Wud7pjddg2luAis0Ib4=";
    };
  }
  {
    name = "N-V-__8AAMR5AwAzZ5_8S2p2COTEf5usBeeT4ORzh-lBGkWy";
    path = fetchGitZig {
      name = "treesitter_query";
      url = "git+https://github.com/tree-sitter-grammars/tree-sitter-query?ref=v0.8.0#a225e21d81201be77da58de614e2b7851735677a";
      hash = "sha256-0y8TbbZKMstjIVFEtq+9Fz44ueRup0ngNcJPJEQB/NQ=";
    };
  }
  # Transitive dependencies from libuv
  {
    name = "N-V-__8AABtNRAB58M85Dm0p6z6iRHP3Zz3eyo08HU4EF5mq";
    path = fetchGitZig {
      name = "libuv-source";
      url = "git+https://github.com/libuv/libuv?ref=v1.51.0#5152db2cbfeb5582e9c27c5ea1dba2cd9e10759b";
      hash = "sha256-ayTk3qkeeAjrGj5ab7wF7vpWI8XWS1EeKKUqzaD/LY0=";
    };
  }
  # Transitive dependencies from libiconv
  {
    name = "N-V-__8AAFwJUgGJcIFZ3fj0Q9U_KtvhHdZXlLz1FcAuIcmX";
    path = fetchZig {
      name = "libiconv-source";
      url = "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.18.tar.gz";
      hash = "sha256-Owj19Pm064LxUacEC/1v5sb7ki7+SxZZxm6pMydpZeg=";
    };
  }
  # Transitive dependencies from utf8proc (vendored in deps/)
  {
    name = "N-V-__8AAJeuKAB2qHg7gyQ3UofhVFaJ3Zn4gUjO47OdbRIB";
    path = fetchGitZig {
      name = "utf8proc-source";
      url = "git+https://github.com/juliastrings/utf8proc?ref=v2.11.2#90daf9f396cfec91668758eb9cc54bd5248a6b89";
      hash = "sha256-/+/IrsLQ9ykuVOaItd2ZbX60pPlP2omvS1qJz51AnWA=";
    };
  }
  # Transitive dependencies from unibilium (vendored in deps/)
  {
    name = "N-V-__8AADO1CgCggvx73yptnBlXbEm7TjOSO6VGIqc0CvYR";
    path = fetchGitZig {
      name = "unibilium-source";
      url = "git+https://github.com/neovim/unibilium?ref=v2.1.2#bfcb0350129dd76893bc90399cf37c45812268a2";
      hash = "sha256-6bFZtR8TUZJembRBj6wUUCyurUdsn3vDGnCzCti/ESc=";
    };
  }
  # Transitive dependencies from zlua - LuaJIT
  {
    name = "N-V-__8AACcgQgCuLYTPzCp6pnBmFJHyG77RAtM13hjOfTaG";
    path = fetchZig {
      name = "luajit-source";
      url = "https://github.com/LuaJIT/LuaJIT/archive/c525bcb9024510cad9e170e12b6209aedb330f83.tar.gz";
      hash = "sha256-6yCv/HCp6XqKDh4LEEVvIg/KdjehmOSpN7X8gn3R75U=";
    };
  }
  # Lua 5.1.5 - used for build platform tools when cross-compiling (instead of LuaJIT)
  {
    name = "N-V-__8AABAhDAAIlXL7OA-0Z5sWQh_FOFGoImvOvJzkRGOg";
    path = fetchZig {
      name = "lua51-source";
      url = "https://www.lua.org/ftp/lua-5.1.5.tar.gz";
      hash = "sha256-JkD8VqeV8p0o7xXhPDSkfiI5YLAkDoywqC2bBzhpUzM=";
    };
  }
  ];

in
linkFarm "neovim-zig-deps" baseDeps
