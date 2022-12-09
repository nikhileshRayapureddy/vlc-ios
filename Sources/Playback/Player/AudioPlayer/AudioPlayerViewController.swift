/*****************************************************************************
 * AudioPlayerViewController.swift
 * VLC for iOS
 *****************************************************************************
 * Copyright © 2022 VLC authors and VideoLAN
 *
 * Authors: Diogo Simao Marques <dogo@videolabs.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import UIKit

@objc (VLCAudioPlayerViewControllerDelegate)
protocol AudioPlayerViewControllerDelegate: AnyObject {
    func audioPlayerViewControllerDidMinimize(_ audioPlayerViewController: AudioPlayerViewController)
    func audioPlayerViewControllerDidClose(_ audioPlayerViewController: AudioPlayerViewController)
    func audioPlayerViewControllerShouldBeDisplayed(_ audioPlayerViewController: AudioPlayerViewController) -> Bool
}

@objc (VLCAudioPlayerViewController)
class AudioPlayerViewController: PlayerViewController {
    // MARK: - Properties

    @objc weak var delegate: AudioPlayerViewControllerDelegate?

    private var isQueueHidden: Bool = true

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        get { return UIInterfaceOrientationMask.portrait }
    }

    lazy var audioPlayerView: AudioPlayerView = {
        let audioPlayerView: AudioPlayerView = Bundle.main.loadNibNamed("AudioPlayerView", owner: nil)?.first as! AudioPlayerView
        audioPlayerView.delegate = self
        return audioPlayerView
    }()

    private lazy var moreOptionsButton: UIButton = {
        let moreOptionsButton = UIButton(type: .custom)
        moreOptionsButton.setImage(UIImage(named: "iconMoreOptions"), for: .normal)
        moreOptionsButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        moreOptionsButton.addTarget(self, action: #selector(handleMoreOptionsButton), for: .touchUpInside)
        return moreOptionsButton
    }()

    private lazy var equalizerPopupTopConstraint: NSLayoutConstraint = {
        equalizerPopupView.topAnchor.constraint(equalTo: audioPlayerView.navigationBarView.topAnchor, constant: 10)
    }()

    private lazy var equalizerPopupBottomConstraint: NSLayoutConstraint = {
        equalizerPopupView.bottomAnchor.constraint(equalTo: audioPlayerView.progressionView.topAnchor, constant: -10)
    }()

    // MARK: - Init

    @objc override init(services: Services, playerController: PlayerController) {
        super.init(services: services, playerController: playerController)

        self.playerController.delegate = self
        mediaNavigationBar.addMoreOptionsButton(moreOptionsButton)
        audioPlayerView.setupNavigationBar(with: mediaNavigationBar)
        audioPlayerView.setupThumbnailView()
        audioPlayerView.setupBackgroundColor()
        audioPlayerView.setupPlayerControls()
        audioPlayerView.setupProgressView(with: mediaScrubProgressBar)
        self.view = audioPlayerView
        setupOptionsNavigationBar()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
        playbackService.delegate = self
        playbackService.recoverPlaybackState()
        seekBy = UserDefaults.standard.integer(forKey: kVLCSettingSetCustomSeek)
        audioPlayerView.setupThumbnailView()
        audioPlayerView.setupBackgroundColor()
    }

    override func viewWillDisappear(_ animated: Bool) {
        playerController.isInterfaceLocked = false
    }

    // MARK: Public methods

    override func showPopup(_ popupView: PopupView, with contentView: UIView, accessoryViewsDelegate: PopupViewAccessoryViewsDelegate? = nil) {
        moreOptionsButton.isEnabled = false
        super.showPopup(popupView, with: contentView, accessoryViewsDelegate: accessoryViewsDelegate)

        let iPhone5width: CGFloat = 320
        let leadingConstraint = popupView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10)
        let trailingConstraint = popupView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        leadingConstraint.priority = .required
        trailingConstraint.priority = .required

        let newConstraints = [
            equalizerPopupTopConstraint,
            equalizerPopupBottomConstraint,
            leadingConstraint,
            trailingConstraint,
            popupView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            popupView.widthAnchor.constraint(greaterThanOrEqualToConstant: iPhone5width)
        ]

        NSLayoutConstraint.activate(newConstraints)
    }

    @objc func setupQueueViewController(with qvc: QueueViewController) {
        queueViewController = qvc
        queueViewController?.delegate = nil
    }

    @objc func handleMoreOptionsButton() {
        present(moreOptionsActionSheet, animated: false) {
            [unowned self] in
            self.moreOptionsActionSheet.interfaceDisabled = self.playerController.isInterfaceLocked
        }
    }

    // MARK: - Private methods

    private func setupOptionsNavigationBar() {
        let padding: CGFloat = 10.0

        view.addSubview(optionsNavigationBar)
        NSLayoutConstraint.activate([
            optionsNavigationBar.topAnchor.constraint(equalTo: audioPlayerView.navigationBarView.bottomAnchor, constant: padding),
            optionsNavigationBar.trailingAnchor.constraint(equalTo: audioPlayerView.trailingAnchor, constant: -padding)
        ])
    }

    private func showPlayqueue(from qvc: QueueViewController) {
        qvc.view.removeFromSuperview()
        qvc.removeFromParent()
        qvc.show()
        qvc.topView.isHidden = true
        addChild(qvc)
        qvc.didMove(toParent: self)
        view.layoutIfNeeded()
        qvc.bottomConstraint?.constant = 0
        UIView.animate(withDuration: 0.3, animations: {
            self.view.layoutIfNeeded()
        })
        qvc.reloadBackground(with: audioPlayerView.thumbnailImageView.image)
        qvc.delegate = nil
    }

    private func updateNavigationBar(with title: String?) {
        mediaNavigationBar.setMediaTitleLabelText(title)
    }

    private func setPlayerInterfaceEnabled(_ enabled: Bool) {
        mediaNavigationBar.closePlaybackButton.isEnabled = enabled
        mediaNavigationBar.queueButton.isEnabled = enabled
        mediaNavigationBar.deviceButton.isEnabled = enabled
        if #available(iOS 11.0, *) {
            mediaNavigationBar.airplayRoutePickerView.isUserInteractionEnabled = enabled
            mediaNavigationBar.airplayRoutePickerView.alpha = !enabled ? 0.5 : 1
        } else {
            mediaNavigationBar.airplayVolumeView.isUserInteractionEnabled = enabled
            mediaNavigationBar.airplayVolumeView.alpha = !enabled ? 0.5 : 1
        }

        mediaScrubProgressBar.progressSlider.isEnabled = enabled
        mediaScrubProgressBar.remainingTimeButton.isEnabled = enabled

        audioPlayerView.setControlsEnabled(enabled)

        playerController.isInterfaceLocked = !enabled
    }
}

// MARK: - AudioPlayerViewDelegate

extension AudioPlayerViewController: AudioPlayerViewDelegate {
    func audioPlayerViewDelegateGetThumbnail(_ audioPlayerView: AudioPlayerView) -> UIImage? {
        guard let image = playbackService.metadata.artworkImage else {
            return PresentationTheme.current.isDark ? UIImage(named: "song-placeholder-dark")
                                                    : UIImage(named: "song-placeholder-white")
        }

        return image
    }

    func audioPlayerViewDelegateDidTapBackwardButton(_ audioPlayerView: AudioPlayerView) {
        playbackService.jumpBackward(Int32(seekBy))
    }

    func audioPlayerViewDelegateDidTapPreviousButton(_ audioPlayerView: AudioPlayerView) {
        playbackService.previous()
    }

    func audioPlayerViewDelegateDidTapPlayButton(_ audioPlayerView: AudioPlayerView) {
        playbackService.playPause()
        audioPlayerView.updatePlayButton(isPlaying: playbackService.isPlaying)
    }

    func audioPlayerViewDelegateDidTapNextButton(_ audioPlayerView: AudioPlayerView) {
        playbackService.next()
    }

    func audioPlayerViewDelegateDidTapForwardButton(_ audioPlayerView: AudioPlayerView) {
        playbackService.jumpForward(Int32(seekBy))
    }
}

// MARK: - VLCPlaybackServiceDelegate

extension AudioPlayerViewController {
    func prepare(forMediaPlayback playbackService: PlaybackService) {
        audioPlayerView.updatePlayButton(isPlaying: playbackService.isPlaying)

        let title: String? = playbackService.metadata.title
        audioPlayerView.updateTitleLabel(with: title, isQueueHidden: isQueueHidden)
        updateNavigationBar(with: isQueueHidden ? nil : title)

        if let qvc = queueViewController, !isQueueHidden {
            showPlayqueue(from: qvc)
        } else if isQueueHidden {
            audioPlayerView.thumbnailView.isHidden = false
        }
    }

    func mediaPlayerStateChanged(_ currentState: VLCMediaPlayerState,
                                 isPlaying: Bool,
                                 currentMediaHasTrackToChooseFrom: Bool, currentMediaHasChapters: Bool,
                                 for playbackService: PlaybackService) {
        audioPlayerView.updatePlayButton(isPlaying: isPlaying)

        if let queueCollectionView = queueViewController?.queueCollectionView {
            queueCollectionView.reloadData()
        }
    }

    func displayMetadata(for playbackService: PlaybackService, metadata: VLCMetaData) {
        audioPlayerView.updateTitleLabel(with: metadata.title, isQueueHidden: isQueueHidden)
        updateNavigationBar(with: isQueueHidden ? nil : metadata.title)
        audioPlayerView.setupThumbnailView()
        audioPlayerView.setupBackgroundColor()

        if let qvc = queueViewController, !isQueueHidden {
            qvc.reloadBackground(with: audioPlayerView.thumbnailImageView.image)
        }
    }
}

// MARK: - PlayerControllerDelegate

extension AudioPlayerViewController: PlayerControllerDelegate {
    func playerControllerExternalScreenDidConnect(_ playerController: PlayerController) {
        // TODO
    }

    func playerControllerExternalScreenDidDisconnect(_ playerController: PlayerController) {
        // TODO
    }

    func playerControllerApplicationBecameActive(_ playerController: PlayerController) {
        // TODO
    }

    func playerControllerPlaybackDidStop(_ playerController: PlayerController) {
        delegate?.audioPlayerViewControllerDidMinimize(self)
    }
}

// MARK: - MediaNavigationBarDelegate

extension AudioPlayerViewController {
    override func mediaNavigationBarDidTapClose(_ mediaNavigationBar: MediaNavigationBar) {
        if playbackService.isPlaying {
            delegate?.audioPlayerViewControllerDidMinimize(self)
        } else {
            playbackService.stopPlayback()
            self.dismiss(animated: true)
            isQueueHidden = true
        }
    }

    func mediaNavigationBarDidToggleQueueView(_ mediaNavigationBar: MediaNavigationBar) {
        let title: String? = playbackService.metadata.title
        updateNavigationBar(with: !isQueueHidden ? nil : title)
        audioPlayerView.updateTitleLabel(with: title, isQueueHidden: !isQueueHidden)

        audioPlayerView.thumbnailView.isHidden = isQueueHidden
        audioPlayerView.playqueueView.isHidden = !isQueueHidden

        if let qvc = queueViewController, isQueueHidden {
            showPlayqueue(from: qvc)
        } else if let qvc = queueViewController, !isQueueHidden {
            qvc.dismissFromAudioPlayer()
        }

        isQueueHidden = !isQueueHidden
    }

    override func mediaNavigationBarDidCloseLongPress(_ mediaNavigationBar: MediaNavigationBar) {
        super.mediaNavigationBarDidCloseLongPress(mediaNavigationBar)
        isQueueHidden = true
    }
}

// MARK: - MediaMoreOptionsActionSheetDelegate

extension AudioPlayerViewController {
    override func mediaMoreOptionsActionSheetDidToggleInterfaceLock(state: Bool) {
        setPlayerInterfaceEnabled(!state)
    }

    override func mediaMoreOptionsActionSheetDisplayAddBookmarksView(_ bookmarksView: AddBookmarksView) {
        super.mediaMoreOptionsActionSheetDisplayAddBookmarksView(bookmarksView)

        if let bookmarksView = addBookmarksView {
            view.addSubview(bookmarksView)
            NSLayoutConstraint.activate([
                bookmarksView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                bookmarksView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                bookmarksView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                bookmarksView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
                bookmarksView.bottomAnchor.constraint(lessThanOrEqualTo: audioPlayerView.controlsStackView.topAnchor),
            ])
        }
    }
}

// MARK: - PopupViewDelegate

extension AudioPlayerViewController {
    override func popupViewDidClose(_ popupView: PopupView) {
        super.popupViewDidClose(popupView)
        moreOptionsButton.isEnabled = true
    }
}