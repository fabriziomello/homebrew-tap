class TimescaledbToolkit < Formula
  desc "Extension for more hyperfunctions, fully compatible with TimescaleDB and PostgreSQL"
  homepage "https://www.timescale.com"
  url "https://github.com/timescale/timescaledb-toolkit/archive/refs/tags/1.12.0.tar.gz"
  sha256 "a4fe2079880d6ab7b26f9a38510fd099beae81288e40e928622738bc0d9ded58"
  head "https://github.com/timescale/timescaledb-toolkit.git", branch: "main"

  bottle do
    root_url "https://github.com/timescale/timescaledb-toolkit/releases/download/1.11.0"
    sha256 cellar: :any, arm64_monterey: "b170f821963811ebbf03fa473b50d6468bf87bccd3ea5b9e29dba71524d9c981"
    sha256 cellar: :any, arm64_ventura: "7360783972362f1ee9343ca20d5b8a11b1d7a4bc53f69e29a45431dd5e57fa96"
  end

  depends_on "rust" => :build
  depends_on "rustfmt" => :build
  depends_on "postgresql@14"

  def postgresql
    Formula["postgresql@14"]
  end

  resource "cargo-pgx" do
    url "https://github.com/tcdi/pgx/archive/refs/tags/v0.5.4.tar.gz"
    sha256 "7c6b5e7fdc6b974b726bb4b965ae8e9dacecc059db1a59b1ec471edb090b4454"
  end

  def install
    ENV["PG_CONFIG"] = postgresql.opt_bin/"pg_config"
    ENV["PGX_HOME"] = buildpath

    resource("cargo-pgx").stage "pgx"
    system "cargo", "install", "--locked", "--path", "pgx/cargo-pgx"
    system "cargo", "pgx", "init", "--pg14", "pg_config"

    cd "extension" do
      system "cargo", "pgx", "package"
    end

    system "cargo", "run", "--bin", "post-install", "--", "--dir", "target/release/timescaledb_toolkit-pg14"

    (lib/postgresql.name).install Dir["target/release/**/lib/**/timescaledb_toolkit*.so"]
    (share/postgresql.name/"extension").install Dir["target/release/**/share/**/timescaledb_toolkit--*.sql"]
    (share/postgresql.name/"extension").install Dir["target/release/**/share/**/timescaledb_toolkit.control"]
  end

  test do
    pg_ctl = postgresql.opt_bin/"pg_ctl"
    psql = postgresql.opt_bin/"psql"
    port = free_port

    system pg_ctl, "initdb", "-D", testpath/"test"
    (testpath/"test/postgresql.conf").write <<~EOS, mode: "a+"

      shared_preload_libraries = 'timescaledb_toolkit-#{version}'
      port = #{port}
    EOS
    system pg_ctl, "start", "-D", testpath/"test", "-l", testpath/"log"
    begin
      system psql, "-p", port.to_s, "-c", "CREATE EXTENSION \"timescaledb_toolkit\";", "postgres"
    ensure
      system pg_ctl, "stop", "-D", testpath/"test"
    end
  end
end
