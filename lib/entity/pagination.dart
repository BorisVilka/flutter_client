
class Pagination {
  late int per_page;
  late int total;
  late int pages;
  late int page;

  Pagination({required this.per_page, required this.total, required this.page, required this.pages});

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      per_page: int.parse(json['per_page'].toString()),
      total: int.parse(json['total'].toString()),
      page: int.parse(json['page'].toString()),
      pages: int.parse(json['pages'].toString()),
    );
  }
}