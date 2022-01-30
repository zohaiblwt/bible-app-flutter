/*
Elisha iOS & Android App
Copyright (C) 2021 Elisha

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
 any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

import 'package:elisha/src/providers/reader_settings_repository_provider.dart';
import 'package:elisha/src/providers/study_tools_repository_provider.dart';
import 'package:elisha/src/ui/components/bible_reader.dart';
import 'package:elisha/src/ui/views/bible_view/components/show_translations_bottom_sheet.dart';
import 'package:flutter/cupertino.dart';

import 'package:canton_design_system/canton_design_system.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:elisha/src/config/exceptions.dart';
import 'package:elisha/src/models/book.dart';
import 'package:elisha/src/models/chapter.dart';
import 'package:elisha/src/models/translation.dart';
import 'package:elisha/src/providers/bible_books_provider.dart';
import 'package:elisha/src/providers/bible_chapters_provider.dart';
import 'package:elisha/src/providers/bible_repository_provider.dart';
import 'package:elisha/src/providers/bible_translations_provider.dart';
import 'package:elisha/src/services/bible_service.dart';
import 'package:elisha/src/ui/components/error_body.dart';
import 'package:elisha/src/ui/components/unexpected_error.dart';
import 'package:screen_brightness/screen_brightness.dart';

class BibleView extends StatefulWidget {
  const BibleView({Key? key}) : super(key: key);

  @override
  _BibleViewState createState() => _BibleViewState();
}

class _BibleViewState extends State<BibleView> {
  var _isBookmarked = false;
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, watch, child) {
        final translationRepo = watch(bibleTranslationsProvider);
        final booksRepo = watch(bibleBooksProvider);
        final chaptersRepo = watch(bibleChaptersProvider);

        return translationRepo.when(
          error: (e, s) {
            if (e is Exceptions) {
              return ErrorBody(e.message, bibleTranslationsProvider);
            }
            return UnexpectedError(bibleTranslationsProvider);
          },
          loading: () => Container(),
          data: (translations) {
            translations.sort((a, b) => a.id!.compareTo(b.id!));
            return booksRepo.when(
              error: (e, s) {
                if (e is Exceptions) {
                  return ErrorBody(e.message, bibleBooksProvider);
                }
                return UnexpectedError(bibleBooksProvider);
              },
              loading: () => Container(),
              data: (books) {
                return chaptersRepo.when(
                  error: (e, s) {
                    if (e is Exceptions) {
                      return ErrorBody(e.message, bibleChaptersProvider);
                    }
                    return UnexpectedError(bibleChaptersProvider);
                  },
                  loading: () => Container(),
                  data: (chapter) {
                    _isBookmarked = _isBookmarked = context
                        .read(studyToolsRepositoryProvider)
                        .bookmarkedChapters
                        .where((e) => e.id == chapter.id)
                        .isNotEmpty;
                    return Responsive(
                      tablet: _buildTabletContent(context, watch, translations, books, chapter),
                      mobile: _buildMobileContent(context, watch, translations, books, chapter),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMobileContent(
    BuildContext context,
    ScopedReader watch,
    List<Translation> translations,
    List<Book> books,
    Chapter chapter,
  ) {
    Widget reader() {
      return SliverToBoxAdapter(
        child: BibleReader(chapter: chapter),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [_buildMobileHeader(context, watch, translations, books, chapter), reader()],
      ),
    );
  }

  Widget _buildTabletContent(
    BuildContext context,
    ScopedReader watch,
    List<Translation> translations,
    List<Book> books,
    Chapter chapter,
  ) {
    Widget reader() {
      return SliverToBoxAdapter(
        child: BibleReader(chapter: chapter),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [_buildTabletHeader(context, watch, translations, books, chapter), reader()],
      ),
    );
  }

  Widget _buildMobileHeader(
      BuildContext context, ScopedReader watch, List<Translation> translations, List<Book> books, Chapter chapter) {
    Widget _previousChapterButton() {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();

          context.read(bibleRepositoryProvider).goToNextPreviousChapter(context, true);
        },
        child: Icon(
          FeatherIcons.chevronLeft,
          size: 27,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    Widget _nextChapterButton() {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();

          context.read(bibleRepositoryProvider).goToNextPreviousChapter(context, false);
        },
        child: Icon(
          FeatherIcons.chevronRight,
          size: 27,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    Widget _bookmarkButton(Chapter chapter) {
      return CantonActionButton(
        onPressed: () async {
          HapticFeedback.lightImpact();

          setState(() {
            _isBookmarked = !_isBookmarked;
          });

          if (_isBookmarked) {
            await context.read(studyToolsRepositoryProvider.notifier).addBookmarkChapter(chapter);
          } else {
            await context.read(studyToolsRepositoryProvider.notifier).removeBookmarkChapter(chapter);
          }
        },
        icon: Icon(
          _isBookmarked ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
          size: 24,
          color: _isBookmarked ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.primary,
        ),
      );
    }

    Widget _readerSettingsButton() {
      return CantonActionButton(
        onPressed: () async {
          HapticFeedback.lightImpact();

          await _showReaderSettingsBottomSheet();
        },
        icon: Icon(
          FeatherIcons.settings,
          size: 24,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    Widget _translationControls(String bookChapterTitle, List<Translation> translations) {
      return Row(
        children: [
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();

              await _showBookAndChapterBottomSheet();
            },
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                color: Theme.of(context).inputDecorationTheme.fillColor,
              ),
              child: Text(
                bookChapterTitle,
                style: Theme.of(context).textTheme.bodyText1?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();

              await showTranslationsBottomSheet(context, translations, setState);
            },
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                color: Theme.of(context).inputDecorationTheme.fillColor,
              ),
              child: Text(
                translations[int.parse(translationID)].abbreviation!,
                style: Theme.of(context).textTheme.bodyText1?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }

    Widget _chapterVerseTranslationControls(List<Translation> translations, List<Book> books, Chapter chapter) {
      var bookChapterTitle = chapter.verses![0].book.name! + ' ' + chapter.number!;

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _previousChapterButton(),
          const Spacer(),
          _readerSettingsButton(),
          const Spacer(),
          _translationControls(bookChapterTitle, translations),
          const Spacer(),
          _bookmarkButton(chapter),
          const Spacer(),
          _nextChapterButton(),
        ],
      );
    }

    return SliverAppBar(
      centerTitle: true,
      floating: true,
      backgroundColor: CantonMethods.alternateCanvasColor(context),
      title: _chapterVerseTranslationControls(translations, books, chapter),
    );
  }

  Widget _buildTabletHeader(
      BuildContext context, ScopedReader watch, List<Translation> translations, List<Book> books, Chapter chapter) {
    Widget _previousChapterButton() {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();

          context.read(bibleRepositoryProvider).goToNextPreviousChapter(context, true);
        },
        child: Icon(
          FeatherIcons.chevronLeft,
          size: 34,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    Widget _nextChapterButton() {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();

          context.read(bibleRepositoryProvider).goToNextPreviousChapter(context, false);
        },
        child: Icon(
          FeatherIcons.chevronRight,
          size: 34,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    Widget _bookmarkButton(Chapter chapter) {
      return CantonActionButton(
        onPressed: () async {
          HapticFeedback.lightImpact();

          setState(() {
            _isBookmarked = !_isBookmarked;
          });

          if (_isBookmarked) {
            await context.read(studyToolsRepositoryProvider.notifier).addBookmarkChapter(chapter);
          } else {
            await context.read(studyToolsRepositoryProvider.notifier).removeBookmarkChapter(chapter);
          }
        },
        icon: Icon(
          _isBookmarked ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
          size: 28,
          color: _isBookmarked ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.primary,
        ),
      );
    }

    Widget _readerSettingsButton() {
      return CantonActionButton(
        onPressed: () async {
          HapticFeedback.lightImpact();

          await _showReaderSettingsBottomSheet();
        },
        icon: Icon(
          FeatherIcons.settings,
          size: 28,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    Widget _translationControls(String bookChapterTitle, List<Translation> translations) {
      return Row(
        children: [
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();

              await _showBookAndChapterBottomSheet();
            },
            child: Container(
              padding: const EdgeInsets.all(18.0),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                color: Theme.of(context).inputDecorationTheme.fillColor,
              ),
              child: Text(
                bookChapterTitle,
                style: Theme.of(context).textTheme.bodyText1?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      height: 1.3,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();

              await showTranslationsBottomSheet(context, translations, setState);
            },
            child: Container(
              padding: const EdgeInsets.all(18.0),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                color: Theme.of(context).inputDecorationTheme.fillColor,
              ),
              child: Text(
                translations[int.parse(translationID)].abbreviation!,
                style: Theme.of(context).textTheme.bodyText1?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      height: 1.3,
                    ),
              ),
            ),
          ),
        ],
      );
    }

    Widget _chapterVerseTranslationControls(List<Translation> translations, List<Book> books, Chapter chapter) {
      var bookChapterTitle = chapter.verses![0].book.name! + ' ' + chapter.number!;

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _previousChapterButton(),
          const Spacer(),
          _readerSettingsButton(),
          const Spacer(),
          _translationControls(bookChapterTitle, translations),
          const Spacer(),
          _bookmarkButton(chapter),
          const Spacer(),
          _nextChapterButton(),
        ],
      );
    }

    return SliverAppBar(
      centerTitle: true,
      floating: true,
      backgroundColor: CantonMethods.alternateCanvasColor(context),
      title: _chapterVerseTranslationControls(translations, books, chapter),
    );
  }

  Future<void> _showReaderSettingsBottomSheet() async {
    var screenBrightness = await ScreenBrightness().system;

    return await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      elevation: 0,
      useRootNavigator: true,
      builder: (context) {
        return Consumer(
          builder: (context, watch, child) {
            return FractionallySizedBox(
              heightFactor: 0.6,
              widthFactor: 0.75,
              child: StatefulBuilder(
                builder: (context, setState) {
                  Widget brightnessControls = Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(CupertinoIcons.sun_min_fill, size: 27),
                        Expanded(
                          child: Slider(
                            value: screenBrightness,
                            onChanged: (val) async {
                              await ScreenBrightness().setScreenBrightness(val);
                              setState(() => screenBrightness = val);
                            },
                          ),
                        ),
                        const Icon(CupertinoIcons.sun_max_fill, size: 34),
                      ],
                    ),
                  );

                  Widget textSizeControls = Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Text Size', style: Theme.of(context).textTheme.headline5),
                        const Spacer(),
                        GestureDetector(
                          onTap: () async {
                            await context.read(readerSettingsRepositoryProvider).decrementBodyTextSize();
                            await context.read(readerSettingsRepositoryProvider).decrementVerseNumberSize();
                          },
                          child: Container(
                            height: 40,
                            width: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              'A',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headline6?.copyWith(
                                    fontSize: 16,
                                    height: 1.25,
                                    color: Theme.of(context).colorScheme.onBackground,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () async {
                            await context.read(readerSettingsRepositoryProvider).incrementBodyTextSize();
                            await context.read(readerSettingsRepositoryProvider).incrementVerseNumberSize();
                          },
                          child: Container(
                            height: 40,
                            width: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              'A',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headline6?.copyWith(
                                    fontSize: 24,
                                    height: 1.25,
                                    color: Theme.of(context).colorScheme.onBackground,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );

                  Widget fontControls = CantonExpansionTile(
                    childrenPadding: EdgeInsets.zero,
                    iconColor: Theme.of(context).colorScheme.primary,
                    title: Text(
                      watch(readerSettingsRepositoryProvider).typeFace,
                      style: Theme.of(context).textTheme.headline5,
                    ),
                    children: [
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              await context.read(readerSettingsRepositoryProvider).setTypeFace('New York');
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'New York',
                                style: Theme.of(context).textTheme.headline4?.copyWith(
                                      fontFamily: 'New York',
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 17),
                          GestureDetector(
                            onTap: () async {
                              await context.read(readerSettingsRepositoryProvider).setTypeFace('Inter');
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Inter',
                                style: Theme.of(context).textTheme.headline4?.copyWith(
                                      fontFamily: 'Inter',
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );

                  Widget lineHeightControls = Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Line Spacing', style: Theme.of(context).textTheme.headline5),
                        const Spacer(),
                        GestureDetector(
                          onTap: () async {
                            await context.read(readerSettingsRepositoryProvider).decrementBodyTextHeight();
                            await context.read(readerSettingsRepositoryProvider).decrementVerseNumberHeight();
                          },
                          child: Container(
                            height: 40,
                            width: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.format_line_spacing,
                                color: Theme.of(context).colorScheme.onBackground, size: 16),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () async {
                            await context.read(readerSettingsRepositoryProvider).incrementBodyTextHeight();
                            await context.read(readerSettingsRepositoryProvider).incrementVerseNumberHeight();
                          },
                          child: Container(
                            height: 40,
                            width: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.format_line_spacing,
                                color: Theme.of(context).colorScheme.onBackground, size: 26),
                          ),
                        ),
                      ],
                    ),
                  );

                  return Consumer(
                    builder: (context, watch, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            brightnessControls,
                            const Divider(height: 34),
                            textSizeControls,
                            const SizedBox(height: 17),
                            const Divider(),
                            const SizedBox(height: 5),
                            fontControls,
                            const Divider(height: 17),
                            const SizedBox(height: 8.5),
                            lineHeightControls,
                            const Divider(height: 34),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showBookAndChapterBottomSheet() async {
    List<Book> books = await BibleService(Dio()).getBooks('');

    Widget _bookCard(Book book) {
      Widget _chapterCard(ChapterId chapter) {
        return GestureDetector(
          onTap: () {
            context.read(bibleRepositoryProvider).changeChapter(context, book.id!, chapter.id!);
            Navigator.of(context, rootNavigator: true).pop();
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.secondary, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                chapter.id.toString(),
                style: Theme.of(context).textTheme.headline6,
              ),
            ),
          ),
        );
      }

      return CantonExpansionTile(
        childrenPadding: const EdgeInsets.symmetric(horizontal: 17),
        title: Text(book.name!, style: Theme.of(context).textTheme.headline6),
        iconColor: Theme.of(context).colorScheme.primary,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 1.0,
                mainAxisSpacing: 10.0,
                crossAxisSpacing: 10.0,
              ),
              itemCount: book.chapters!.length,
              itemBuilder: (context, index) => _chapterCard(book.chapters![index]),
            ),
          ),
        ],
      );
    }

    return await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      elevation: 0,
      useRootNavigator: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.95,
          widthFactor: 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 27),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Books',
                      style: Theme.of(context).textTheme.headline5,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Expanded(
                child: ListView.builder(
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    return Column(
                      children: [
                        _bookCard(books[index]),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
