//
//  Created by Alex.M on 27.05.2022.
//

import SwiftUI

struct AlbumsView: View {
    let albums: [AlbumModel]
    let isLoading: Bool
    @Binding var selected: [MediaModel]
    @Binding var isSent: Bool
    var assetsAction: AssetsLibraryAction?
    var cameraAction: CameraAction?
    
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 100), spacing: 0, alignment: .top)]
    }
    
    private var cellPadding: EdgeInsets {
        EdgeInsets(top: 2, leading: 2, bottom: 8, trailing: 2)
    }
    
    var body: some View {
        ScrollView {
            VStack {
                if let action = assetsAction {
                    PermissionsActionView(action: .library(action))
                }
                if isLoading {
                    ProgressView()
                } else if albums.isEmpty {
                    Text("Empty data")
                        .font(.title3)
                } else {
                    LazyVGrid(columns: columns, spacing: 0) {
                        ForEach(albums) { album in
                            NavigationLink {
                                AlbumView(
                                    title: album.title,
                                    onTapCamera: nil,
                                    medias: album.medias,
                                    isLoading: isLoading,
                                    selected: $selected,
                                    isSent: $isSent,
                                    assetsAction: assetsAction,
                                    cameraAction: cameraAction)
                            } label: {
                                AlbumCell(
                                    viewModel: AlbumViewModel(album: album)
                                )
                                .padding(cellPadding)
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
        }
        .navigationBarItems(
            trailing: Button("Send") {
                isSent = true
            }
                .disabled(selected.isEmpty)
        )
    }
}