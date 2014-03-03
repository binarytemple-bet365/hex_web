defmodule HexWeb.ReleaseTest do
  use HexWebTest.Case

  alias HexWeb.User
  alias HexWeb.Package
  alias HexWeb.Release

  setup do
    { :ok, user } = User.create("eric", "eric@mail.com", "eric")
    { :ok, _ } = Package.create("ecto", user, [])
    { :ok, _ } = Package.create("postgrex", user, [])
    { :ok, _ } = Package.create("decimal", user, [])
    :ok
  end

  test "create release and get" do
    package = Package.get("ecto")
    package_id = package.id
    assert { :ok, Release.Entity[package_id: ^package_id, version: "0.0.1"] } =
           Release.create(package, "0.0.1", "url", "ref", [])
    assert Release.Entity[package_id: ^package_id, version: "0.0.1"] = Release.get(package, "0.0.1")

    assert { :ok, _ } = Release.create(package, "0.0.2", "url", "ref", [])
    assert [ Release.Entity[git_url: "url", git_ref: "ref", version: "0.0.1"],
             Release.Entity[git_url: "url", git_ref: "ref", version: "0.0.2"] ] =
           Release.all(package)
  end

  test "create release with deps" do
    ecto = Package.get("ecto")
    postgrex = Package.get("postgrex")
    decimal = Package.get("decimal")

    assert { :ok, _ } = Release.create(decimal, "0.0.1", "url", "ref", [])
    assert { :ok, _ } = Release.create(decimal, "0.0.2", "url", "ref", [])
    assert { :ok, _ } = Release.create(postgrex, "0.0.1", "url", "ref", [{ "decimal", "~> 0.0.1" }])
    assert { :ok, _ } = Release.create(ecto, "0.0.1", "url", "ref", [{ "decimal", "~> 0.0.2" }, { "postgrex", "== 0.0.1" }])

    release = Release.get(ecto, "0.0.1")
    assert [{"postgrex", "== 0.0.1" }, {"decimal", "~> 0.0.2" }] = release.requirements.to_list
  end

  test "validate release" do
    package = Package.get("ecto")

    assert { :error, [version: "invalid version"] } =
           Release.create(package, "0.1", "url", "ref", [])

    assert { :error, [deps: [{ "decimal", "invalid requirement: \"fail\"" }]] } =
           Release.create(package, "0.1.0", "url", "ref", [{ "decimal", "fail" }])
  end

  test "release version is unique" do
    ecto = Package.get("ecto")
    postgrex = Package.get("postgrex")
    assert { :ok, Release.Entity[] } = Release.create(ecto, "0.0.1", "url", "ref", [])
    assert { :ok, Release.Entity[] } = Release.create(postgrex, "0.0.1", "url", "ref", [])
    assert { :error, _ } = Release.create(ecto, "0.0.1", "url", "ref", [])
  end

  test "update release" do
    decimal = Package.get("decimal")
    postgrex = Package.get("postgrex")

    assert { :ok, _ } = Release.create(decimal, "0.0.1", "url", "ref", [])
    assert { :ok, release } = Release.create(postgrex, "0.0.1", "url", "ref", [{ "decimal", "~> 0.0.1" }])

    Release.update(release, "new_url", "new_ref", [{ "decimal", "~> 0.0.2" }])

    release = Release.get(postgrex, "0.0.1")
    assert release.git_url == "new_url"
    assert release.git_ref == "new_ref"
    assert [{"decimal", "~> 0.0.2" }] = release.requirements.to_list
  end
end