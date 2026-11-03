// Checks the app's plain-JavaScript helpers (app/*.js) on made-up input: node test-js.mjs
import { readFileSync } from "node:fs";
import assert from "node:assert/strict";

const load = (file, names) => {
    const src = readFileSync(new URL(`app/${file}`, import.meta.url), "utf8").replace(/^\.pragma library$/m, "");
    return new Function(`${src}; return { ${names} };`)();
};

// Rename.js: bulk rename
{
    const { bulkNames } = load("Rename.js", "bulkNames");
    const names = ["IMG_001.jpg", "IMG_002.jpg", "notes.tar.gz", ".bashrc"];
    assert.deepEqual(bulkNames(names, "replace", "IMG_", "Trip "), ["Trip 001.jpg", "Trip 002.jpg", "notes.tar.gz", ".bashrc"]);
    assert.deepEqual(bulkNames(names, "replace", "", "x"), names, "nothing to find");
    assert.deepEqual(bulkNames(names, "number", "Holiday", ""), ["Holiday 1.jpg", "Holiday 2.jpg", "Holiday 3.tar.gz", "Holiday 4"]);
    assert.deepEqual(bulkNames(Array(12).fill("a.png").map((n, i) => i + n), "number", " ", "1").slice(0, 2), ["File 01.png", "File 02.png"]);
    assert.deepEqual(bulkNames(["a.txt", "b.txt"], "replace", "a", "b"), ["a.txt", "b.txt"], "b.txt is taken by the batch");
    assert.deepEqual(bulkNames(["a.txt", "a.md"], "replace", "a", "x/"), ["a.txt", "a.md"], "no slashes");
    assert.deepEqual(bulkNames(["ab", "ba"], "replace", "a", ""), ["b", "ba"], "second would clash with the first's new name");
}

// Places.js: bookmarks and network mounts
{
    const { bookmarks, addBookmark, removeBookmark, mountLabel } = load("Places.js", "bookmarks, addBookmark, removeBookmark, mountLabel");
    const text = "file:///home/me/Projects\nfile:///home/me/My%20Stuff Stuff\nsftp://box/srv Box\n";
    assert.deepEqual(bookmarks(text), [{ path: "/home/me/Projects", label: "Projects" }, { path: "/home/me/My Stuff", label: "Stuff" }]);
    const added = addBookmark(text, "/home/me/Two Words");
    assert.ok(added.endsWith("sftp://box/srv Box\nfile:///home/me/Two%20Words\n"), added);
    assert.equal(addBookmark(text, "/home/me/Projects"), text, "already there");
    assert.equal(removeBookmark(added, "/home/me/My Stuff"), "file:///home/me/Projects\nsftp://box/srv Box\nfile:///home/me/Two%20Words\n");
    assert.equal(removeBookmark("file:///a\n", "/a"), "");
    assert.equal(mountLabel("smb-share:server=nas.local,share=photos"), "photos on nas.local");
    assert.equal(mountLabel("sftp:host=example.com,user=me"), "example.com");
    assert.equal(mountLabel("dav:host=cloud.example.com,ssl=true,prefix=%2Fremote.php"), "cloud.example.com");
    assert.equal(mountLabel("odd"), "odd");
}

console.log("ok   Rename.js, Places.js");
