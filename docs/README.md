# More info

## Why it's not on Cinnamon Spices?

Currently, they don't provide a way to upload it with a submenu. And users would have to put it together manually. Which is not what I wanted.

## Translation

.pot file generated with:

```bash
cd actions/checksum_menu@pwlcz
xgettext --language=Shell -o po/nemo_checksum_menu.pot hash_wrapper.sh verify_clipboard.sh ../../docs/translation.dummy
```

## Tests

Basic functionality checked with bats tests.

Manual testing to check localization.
