### Take-home exercise

In the reference design from **experiment 5**, only the lower memory half (i.e., address range 000h-0FFh) is used for storing the LCD codes of lower-case characters. Extend the MIF file so that the upper memory half (i.e., address range 100h-1FFh) stores the LCD codes for upper-case characters. Use a single-bit register to keep track of the case mode. Pressing the left Shift key selects upper-case mode, and pressing the right Shift key selects lower-case mode. The case mode affects only alphabet keys (`a` to `z`); digit keys (`0` to `9`) are displayed the same way in both modes. A Shift key changes the case mode but does not produce a character on the LCD. If Shift keys are pressed more than once between two displayed characters, the last Shift key pressed determines the case of the next alphabet character.

Alphabet and digit keys produce displayed characters and occupy positions in a line. Every key other than an alphabet key, a digit key, left Shift, or right Shift displays a space and occupies one position. For example, pressing Space, Enter, or a punctuation key displays a space. Left Shift and right Shift are ignored by the display and affect only the case mode. The first displayed character occupies position 0, and the last displayed character occupies position 15. As in the in-lab **experiment 5**, the complete line is displayed after all sixteen positions have been filled.

Only two adjacent displayed characters can form a qualifying pair. Both characters must come from alphabet or digit keys. The top line requires a letter immediately followed by a digit, while the bottom line requires a digit immediately followed by a letter. A displayed space is neither a letter nor a digit, so a pair containing that space never qualifies. For example, on the top line, if `A`, Space, and `1` occupy three consecutive positions, neither `A` followed by Space nor Space followed by `1` qualifies. On the bottom line, if `1`, Space, and `A` occupy three consecutive positions, neither `1` followed by Space nor Space followed by `A` qualifies.

#### Top line specification

After the top line is displayed, the rightmost 7-segment display shows the number of consecutive character pairs in which a letter is followed by a digit. Examine every pair of consecutive characters. A qualifying pair may begin at any position from 0 through 14; its starting position is not restricted to even or odd positions.

For example, suppose the top line is:

`BA1CA2DEFGHIJKLM`

The pair `A1` begins at position 1, and the pair `A2` begins at position 4. These are the only letter-to-digit pairs, so the rightmost 7-segment display shows 2.

The following top line produces the maximum count of 8:

`A1B2C3D4E5F6G7H8`

#### Bottom line specification

After the bottom line is displayed, the rightmost 7-segment display shows the number of consecutive character pairs in which a digit is followed by a letter. As for the top line, a qualifying pair may begin at any position from 0 through 14.

For example, suppose the bottom line is:

`1AB2CDEFGHIJKLMN`

The pair `1A` begins at position 0, and the pair `2C` begins at position 3. These are the only digit-to-letter pairs, so the rightmost 7-segment display shows 2.

The following bottom line produces the maximum count of 8:

`1A2B3C4D5E6F7G8H`

For both lines, upper-case and lower-case alphabet characters are letters. The selected case changes the character displayed on the LCD but does not change the pair count. If a completed line contains no qualifying pair, the rightmost 7-segment display shows 0.

The pair count remains visible until the first key that occupies a position in the next line is typed. Pressing either Shift key changes the case mode but leaves the displayed pair count unchanged. The rightmost 7-segment display remains off while the next line is being assembled. The behavior continues by alternating between the top and bottom lines.

Only the behavior of the rightmost 7-segment display is specified. You may use the remaining 7-segment displays and the red and green LEDs for debugging. Transferring a complete line to the LCD controller takes just under 15 us in simulation. Therefore, schedule the next key that occupies a position in `board_events.txt` after this transfer has finished.

Submit your source files and, in your report, write approximately half a page (but not more than a full page) describing your reasoning. Your submission should follow the directory structure from the in-lab experiments, which is already set up in the `exercise` folder. Include your report (in `.pdf`, `.txt`, or `.md` format) in the `exercise/doc` sub-folder.

Your submission is due 16 hours before your next lab session. Late submissions will be penalized.
